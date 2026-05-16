import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'segmentation_service.dart';

class ImageProcessorService {
  static final SegmentationService _segService = SegmentationService();

  /// Automatically isolate the foreground object.
  /// Returns PNG bytes with transparent background, or null on failure.
  static Future<Uint8List?> automaticIsolate(Uint8List imageBytes) async {
    try {
      await _segService.initialize();
      final result = await _segService.segment(imageBytes);
      if (result != null) {
        return result.imageBytes;
      }
    } catch (e) {
      debugPrint('Segmentation failed: $e');
    }
    return null;
  }
}
