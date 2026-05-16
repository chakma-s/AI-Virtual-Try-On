import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ImageProcessorService {
  /// IMPORTANT: Provide a Remove.bg API key here for the best results.
  /// Get a free key at: https://www.remove.bg/api
  static const String _removeBgApiKey = ''; // <-- PUT YOUR API KEY HERE

  /// Automatically isolates an object (like glasses) from the image.
  /// Tries the Remove.bg API first if a key is provided, otherwise falls back to local processing.
  static Future<Uint8List?> automaticIsolate(Uint8List imageBytes) async {
    if (_removeBgApiKey.isNotEmpty) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.remove.bg/v1.0/removebg'),
        );
        request.headers['X-Api-Key'] = _removeBgApiKey;
        request.files.add(
          http.MultipartFile.fromBytes(
            'image_file',
            imageBytes,
            filename: 'item.jpg',
          ),
        );
        request.fields['size'] = 'auto';

        final response = await request.send();
        if (response.statusCode == 200) {
          final resultBytes = await response.stream.toBytes();
          return resultBytes;
        } else {
          debugPrint('Remove.bg API failed with status: ${response.statusCode}');
          // Fall back to local isolate
        }
      } catch (e) {
        debugPrint('Remove.bg API error: $e');
        // Fall back to local isolate
      }
    }
    
    // Fallback: Local color thresholding
    return compute(_processImageIsolate, imageBytes);
  }

  /// Original manual method for reference (now handled by ItemIsolatorScreen)
  static Future<Uint8List?> removeWhiteBackground(Uint8List imageBytes) async {
    return compute(_processImageIsolate, imageBytes);
  }

  /// Local fallback isolation logic (looks for darkest pixels for glasses)
  static Uint8List? _processImageIsolate(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final transparentImage = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 4, 
      );

      // Simple heuristic for glasses: keep darker pixels, make lighter background transparent.
      // Not perfect for all images, which is why the API is recommended.
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;
          
          // Heuristic: If it's a bright background pixel (r, g, b > 180), remove it.
          // This works somewhat for glasses photographed on white tables.
          if (r > 180 && g > 180 && b > 180) {
            transparentImage.setPixelRgba(x, y, r, g, b, 0);
          } else {
            transparentImage.setPixelRgba(x, y, r, g, b, 255);
          }
        }
      }

      return img.encodePng(transparentImage);
    } catch (e) {
      debugPrint('Failed to process image: $e');
      return null;
    }
  }
}
