import 'dart:typed_data';

// Conditionally import web or fallback implementation
import 'segmentation_fallback.dart'
    if (dart.library.js_interop) 'segmentation_web.dart';

/// Result from segmentation — composited PNG bytes.
class SegmentationResult {
  final Uint8List imageBytes;
  SegmentationResult({required this.imageBytes});
}

abstract class SegmentationService {
  Future<bool> initialize();
  Future<SegmentationResult?> segment(Uint8List imageBytes);
  factory SegmentationService() => getSegmentationService();
}
