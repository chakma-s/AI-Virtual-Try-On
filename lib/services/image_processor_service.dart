import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessorService {
  /// Processes a raw image to remove solid white/light backgrounds.
  /// Runs in an isolate to avoid blocking the main UI thread.
  static Future<Uint8List?> removeWhiteBackground(Uint8List imageBytes) async {
    return compute(_processImageIsolate, imageBytes);
  }

  static Uint8List? _processImageIsolate(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Create a new image with an alpha channel
      final transparentImage = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 4, // RGBA
      );

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          
          // Threshold for near-white backgrounds
          if (r > 220 && g > 220 && b > 220) {
            transparentImage.setPixelRgba(x, y, r, g, b, 0);
          } else {
            transparentImage.setPixelRgba(x, y, r, g, b, 255);
          }
        }
      }

      // Encode back to PNG for transparency support
      return img.encodePng(transparentImage);
    } catch (e) {
      debugPrint('Failed to process image: $e');
      return null;
    }
  }
}
