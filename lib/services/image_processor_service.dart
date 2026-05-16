import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'segmentation_service.dart';

/// Processing payload for the isolate.
class _CompositePayload {
  final Uint8List originalBytes;
  final Uint8List mask;
  final int maskW;
  final int maskH;
  final int origW;
  final int origH;
  _CompositePayload(this.originalBytes, this.mask, this.maskW, this.maskH, this.origW, this.origH);
}

class ImageProcessorService {
  static final SegmentationService _segService = SegmentationService();

  /// Automatically isolate the foreground object from its background.
  /// Uses AI segmentation (U²-Net on web) with local fallback.
  /// Returns isolated PNG bytes, or null on failure.
  static Future<Uint8List?> automaticIsolate(Uint8List imageBytes) async {
    try {
      // Initialize segmentation service
      await _segService.initialize();

      // Run AI segmentation
      final result = await _segService.segment(imageBytes);

      if (result != null) {
        // Quality gate: check mask coverage
        int fgPixels = 0;
        for (int i = 0; i < result.mask.length; i++) {
          if (result.mask[i] > 128) fgPixels++;
        }
        final coverage = fgPixels / result.mask.length;

        if (coverage > 0.03 && coverage < 0.97) {
          // Good mask — composite in isolate
          final payload = _CompositePayload(
            imageBytes,
            result.mask,
            result.maskWidth,
            result.maskHeight,
            result.originalWidth,
            result.originalHeight,
          );
          return compute(_compositeWithMask, payload);
        }
      }
    } catch (e) {
      debugPrint('AI segmentation failed: $e');
    }

    // Fallback: simple local processing
    return compute(_simpleLocalIsolate, imageBytes);
  }

  /// Composite original image with the segmentation mask.
  /// Upscales the mask if needed, applies feathering, outputs PNG with alpha.
  static Uint8List? _compositeWithMask(_CompositePayload p) {
    try {
      final original = img.decodeImage(p.originalBytes);
      if (original == null) return null;

      final origW = original.width;
      final origH = original.height;

      // Upscale mask to original resolution using bilinear interpolation
      final upscaled = Uint8List(origW * origH);
      final scaleX = p.maskW / origW;
      final scaleY = p.maskH / origH;

      for (int y = 0; y < origH; y++) {
        for (int x = 0; x < origW; x++) {
          final srcX = x * scaleX;
          final srcY = y * scaleY;
          final x0 = srcX.floor().clamp(0, p.maskW - 1);
          final y0 = srcY.floor().clamp(0, p.maskH - 1);
          final x1 = (x0 + 1).clamp(0, p.maskW - 1);
          final y1 = (y0 + 1).clamp(0, p.maskH - 1);
          final fx = srcX - x0;
          final fy = srcY - y0;

          final v00 = p.mask[y0 * p.maskW + x0];
          final v10 = p.mask[y0 * p.maskW + x1];
          final v01 = p.mask[y1 * p.maskW + x0];
          final v11 = p.mask[y1 * p.maskW + x1];

          final val = (v00 * (1 - fx) * (1 - fy) +
                  v10 * fx * (1 - fy) +
                  v01 * (1 - fx) * fy +
                  v11 * fx * fy)
              .round()
              .clamp(0, 255);
          upscaled[y * origW + x] = val;
        }
      }

      // Threshold
      for (int i = 0; i < upscaled.length; i++) {
        upscaled[i] = upscaled[i] > 128 ? 255 : 0;
      }

      // Feather edges: 3px Gaussian blur on the mask
      final feathered = _gaussianBlurMask(upscaled, origW, origH, 3);

      // Composite: original × feathered mask
      final output = img.Image(width: origW, height: origH, numChannels: 4);
      for (int y = 0; y < origH; y++) {
        for (int x = 0; x < origW; x++) {
          final pixel = original.getPixel(x, y);
          final alpha = feathered[y * origW + x];
          output.setPixelRgba(
            x, y,
            pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), alpha,
          );
        }
      }

      return Uint8List.fromList(img.encodePng(output));
    } catch (e) {
      return null;
    }
  }

  /// Simple local isolation (improved from basic threshold).
  static Uint8List? _simpleLocalIsolate(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final w = image.width;
      final h = image.height;

      // Sample border pixels for background color
      double sumR = 0, sumG = 0, sumB = 0;
      int count = 0;
      for (int x = 0; x < w; x++) {
        for (int d = 0; d < 3 && d < h; d++) {
          final p1 = image.getPixel(x, d);
          sumR += p1.r.toInt(); sumG += p1.g.toInt(); sumB += p1.b.toInt(); count++;
          final p2 = image.getPixel(x, h - 1 - d);
          sumR += p2.r.toInt(); sumG += p2.g.toInt(); sumB += p2.b.toInt(); count++;
        }
      }
      for (int y = 3; y < h - 3; y++) {
        for (int d = 0; d < 3 && d < w; d++) {
          final p1 = image.getPixel(d, y);
          sumR += p1.r.toInt(); sumG += p1.g.toInt(); sumB += p1.b.toInt(); count++;
          final p2 = image.getPixel(w - 1 - d, y);
          sumR += p2.r.toInt(); sumG += p2.g.toInt(); sumB += p2.b.toInt(); count++;
        }
      }

      final bgR = sumR / count;
      final bgG = sumG / count;
      final bgB = sumB / count;
      const threshold = 50.0; // Color distance threshold

      final output = img.Image(width: w, height: h, numChannels: 4);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final pixel = image.getPixel(x, y);
          final dr = pixel.r.toInt() - bgR;
          final dg = pixel.g.toInt() - bgG;
          final db = pixel.b.toInt() - bgB;
          final dist = (dr * dr + dg * dg + db * db);
          final distSqrt = dist > 0 ? dist / (255 * 255 * 3) * 1000 : 0;

          if (distSqrt < threshold) {
            // Background — transparent
            output.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 0);
          } else {
            // Foreground — opaque
            output.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
          }
        }
      }

      return Uint8List.fromList(img.encodePng(output));
    } catch (e) {
      return null;
    }
  }

  /// Apply Gaussian-like blur to a mask for edge feathering.
  static Uint8List _gaussianBlurMask(Uint8List mask, int w, int h, int radius) {
    final result = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double sum = 0, weight = 0;
        for (int ky = -radius; ky <= radius; ky++) {
          for (int kx = -radius; kx <= radius; kx++) {
            final nx = x + kx, ny = y + ky;
            if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
            final d = (kx * kx + ky * ky).toDouble();
            final g = 1.0 / (1.0 + d);
            sum += mask[ny * w + nx] * g;
            weight += g;
          }
        }
        result[y * w + x] = (sum / weight).round().clamp(0, 255);
      }
    }
    return result;
  }
}
