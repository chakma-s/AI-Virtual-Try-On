import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'segmentation_service.dart';

/// Fallback segmentation using improved local color analysis.
/// Used on mobile (until TFLite is set up) and when ONNX fails.
class SegmentationServiceFallback implements SegmentationService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<SegmentationResult?> segment(Uint8List imageBytes) async {
    final result = await compute(_localSegment, imageBytes);
    return result;
  }

  static SegmentationResult? _localSegment(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final w = image.width;
      final h = image.height;

      // Step 1: Sample border pixels to estimate background color
      final List<int> bgR = [], bgG = [], bgB = [];
      void samplePixel(int x, int y) {
        final p = image.getPixel(x, y);
        bgR.add(p.r.toInt());
        bgG.add(p.g.toInt());
        bgB.add(p.b.toInt());
      }
      // Sample 5-pixel border from all edges
      for (int x = 0; x < w; x++) {
        for (int d = 0; d < 5 && d < h; d++) {
          samplePixel(x, d);
          samplePixel(x, h - 1 - d);
        }
      }
      for (int y = 5; y < h - 5; y++) {
        for (int d = 0; d < 5 && d < w; d++) {
          samplePixel(d, y);
          samplePixel(w - 1 - d, y);
        }
      }

      // Compute mean and std of background
      final n = bgR.length;
      if (n == 0) return null;
      final meanR = bgR.reduce((a, b) => a + b) / n;
      final meanG = bgG.reduce((a, b) => a + b) / n;
      final meanB = bgB.reduce((a, b) => a + b) / n;
      double varR = 0, varG = 0, varB = 0;
      for (int i = 0; i < n; i++) {
        varR += (bgR[i] - meanR) * (bgR[i] - meanR);
        varG += (bgG[i] - meanG) * (bgG[i] - meanG);
        varB += (bgB[i] - meanB) * (bgB[i] - meanB);
      }
      final stdR = (varR / n).clamp(100, 10000); // sigma squared
      final stdG = (varG / n).clamp(100, 10000);
      final stdB = (varB / n).clamp(100, 10000);

      // Step 2: Generate probability mask using color distance
      final mask = Uint8List(w * h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = image.getPixel(x, y);
          final dr = p.r.toInt() - meanR;
          final dg = p.g.toInt() - meanG;
          final db = p.b.toInt() - meanB;
          final dist = (dr * dr / stdR) + (dg * dg / stdG) + (db * db / stdB);
          // Sigmoid-like conversion: larger distance = more likely foreground
          final prob = 1.0 - (1.0 / (1.0 + dist * 0.3));
          mask[y * w + x] = (prob * 255).round().clamp(0, 255);
        }
      }

      // Step 3: Threshold at 128
      for (int i = 0; i < mask.length; i++) {
        mask[i] = mask[i] > 128 ? 255 : 0;
      }

      // Step 4: Morphological close (dilate then erode) - fill small holes
      _dilate(mask, w, h, 2);
      _erode(mask, w, h, 2);

      // Step 5: Morphological open (erode then dilate) - remove noise
      _erode(mask, w, h, 1);
      _dilate(mask, w, h, 1);

      // Step 6: Keep largest connected component
      _keepLargestComponent(mask, w, h);

      return SegmentationResult(
        mask: mask,
        maskWidth: w,
        maskHeight: h,
        originalWidth: w,
        originalHeight: h,
      );
    } catch (e) {
      return null;
    }
  }

  static void _dilate(Uint8List mask, int w, int h, int radius) {
    final result = Uint8List.fromList(mask);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y * w + x] == 255) continue;
        bool found = false;
        for (int dy = -radius; dy <= radius && !found; dy++) {
          for (int dx = -radius; dx <= radius && !found; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
              if (mask[ny * w + nx] == 255) found = true;
            }
          }
        }
        if (found) result[y * w + x] = 255;
      }
    }
    for (int i = 0; i < mask.length; i++) mask[i] = result[i];
  }

  static void _erode(Uint8List mask, int w, int h, int radius) {
    final result = Uint8List.fromList(mask);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y * w + x] == 0) continue;
        bool allFg = true;
        for (int dy = -radius; dy <= radius && allFg; dy++) {
          for (int dx = -radius; dx <= radius && allFg; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
              if (mask[ny * w + nx] == 0) allFg = false;
            } else {
              allFg = false;
            }
          }
        }
        if (!allFg) result[y * w + x] = 0;
      }
    }
    for (int i = 0; i < mask.length; i++) mask[i] = result[i];
  }

  static void _keepLargestComponent(Uint8List mask, int w, int h) {
    final labels = List<int>.filled(w * h, -1);
    int nextLabel = 0;
    final componentSizes = <int, int>{};

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (mask[y * w + x] == 0 || labels[y * w + x] != -1) continue;
        // Flood fill
        final label = nextLabel++;
        int size = 0;
        final stack = <int>[y * w + x];
        while (stack.isNotEmpty) {
          final idx = stack.removeLast();
          if (idx < 0 || idx >= w * h) continue;
          if (labels[idx] != -1 || mask[idx] == 0) continue;
          labels[idx] = label;
          size++;
          final px = idx % w, py = idx ~/ w;
          if (px > 0) stack.add(py * w + px - 1);
          if (px < w - 1) stack.add(py * w + px + 1);
          if (py > 0) stack.add((py - 1) * w + px);
          if (py < h - 1) stack.add((py + 1) * w + px);
        }
        componentSizes[label] = size;
      }
    }

    if (componentSizes.isEmpty) return;
    final largestLabel = componentSizes.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    for (int i = 0; i < mask.length; i++) {
      if (mask[i] == 255 && labels[i] != largestLabel) {
        mask[i] = 0;
      }
    }
  }
}

SegmentationService getSegmentationService() => SegmentationServiceFallback();
