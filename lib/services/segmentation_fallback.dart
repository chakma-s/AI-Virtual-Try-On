import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'segmentation_service.dart';

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
      final w = image.width, h = image.height;

      // Sample border pixels for background color
      final List<int> bR = [], bG = [], bB = [];
      void sample(int x, int y) {
        final p = image.getPixel(x, y);
        bR.add(p.r.toInt()); bG.add(p.g.toInt()); bB.add(p.b.toInt());
      }
      for (int x = 0; x < w; x++) {
        for (int d = 0; d < 5 && d < h; d++) { sample(x, d); sample(x, h - 1 - d); }
      }
      for (int y = 5; y < h - 5; y++) {
        for (int d = 0; d < 5 && d < w; d++) { sample(d, y); sample(w - 1 - d, y); }
      }

      final n = bR.length;
      if (n == 0) return null;
      final mR = bR.reduce((a, b) => a + b) / n;
      final mG = bG.reduce((a, b) => a + b) / n;
      final mB = bB.reduce((a, b) => a + b) / n;
      double vR = 0, vG = 0, vB = 0;
      for (int i = 0; i < n; i++) {
        vR += (bR[i] - mR) * (bR[i] - mR);
        vG += (bG[i] - mG) * (bG[i] - mG);
        vB += (bB[i] - mB) * (bB[i] - mB);
      }
      final sR = (vR / n).clamp(100, 10000);
      final sG = (vG / n).clamp(100, 10000);
      final sB = (vB / n).clamp(100, 10000);

      // Generate alpha from color distance
      final out = img.Image(width: w, height: h, numChannels: 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = image.getPixel(x, y);
          final dr = p.r.toInt() - mR, dg = p.g.toInt() - mG, db = p.b.toInt() - mB;
          final dist = (dr * dr / sR) + (dg * dg / sG) + (db * db / sB);
          final prob = (1.0 - (1.0 / (1.0 + dist * 0.3))).clamp(0.0, 1.0);
          final alpha = (prob * 255).round().clamp(0, 255);
          out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha < 30 ? 0 : alpha > 220 ? 255 : alpha);
        }
      }
      return SegmentationResult(imageBytes: Uint8List.fromList(img.encodePng(out)));
    } catch (e) { return null; }
  }
}

SegmentationService getSegmentationService() => SegmentationServiceFallback();
