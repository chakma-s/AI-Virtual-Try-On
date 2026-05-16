import 'dart:typed_data';

// Conditionally import web or fallback implementation
import 'segmentation_fallback.dart'
    if (dart.library.js_interop) 'segmentation_web.dart';

/// Service for AI-based salient object segmentation.
/// On web: uses ONNX Runtime with U²-Net model.
/// On mobile: falls back to improved local algorithm.
abstract class SegmentationService {
  /// Initialize the model (may download on first use).
  Future<bool> initialize();

  /// Segment the foreground object from background.
  /// Returns a probability mask as Uint8List where 255 = foreground, 0 = background.
  /// Returns null if segmentation fails.
  Future<SegmentationResult?> segment(Uint8List imageBytes);

  /// Factory to get the correct platform implementation.
  factory SegmentationService() => getSegmentationService();
}

/// Result from segmentation: the mask + original dimensions.
class SegmentationResult {
  final Uint8List mask; // 0-255 probability mask
  final int maskWidth;
  final int maskHeight;
  final int originalWidth;
  final int originalHeight;

  SegmentationResult({
    required this.mask,
    required this.maskWidth,
    required this.maskHeight,
    required this.originalWidth,
    required this.originalHeight,
  });
}
