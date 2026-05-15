/// Represents a detected face landmark point.
class FaceLandmark {
  /// X position (normalized 0.0 - 1.0 or pixel coordinates).
  final double x;

  /// Y position (normalized 0.0 - 1.0 or pixel coordinates).
  final double y;

  /// Z position (depth, normalized).
  final double z;

  /// MediaPipe landmark index.
  final int index;

  const FaceLandmark({
    required this.x,
    required this.y,
    this.z = 0.0,
    this.index = -1,
  });

  @override
  String toString() =>
      'FaceLandmark($index: ${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Represents all detected landmarks for a single face.
class FaceData {
  /// All 468 face mesh landmarks in pixel coordinates.
  final List<FaceLandmark> landmarks;

  /// Image width used for detection.
  final int imageWidth;

  /// Image height used for detection.
  final int imageHeight;

  /// Head rotation angles estimated from landmarks.
  final double headYaw;    // Left-right rotation
  final double headPitch;  // Up-down rotation
  final double headRoll;   // Tilt rotation

  const FaceData({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
    this.headYaw = 0.0,
    this.headPitch = 0.0,
    this.headRoll = 0.0,
  });

  /// Get a specific landmark by its MediaPipe index.
  FaceLandmark operator [](int index) => landmarks[index];

  /// Number of detected landmarks.
  int get count => landmarks.length;

  /// Whether a full face mesh was detected (468 points).
  bool get isFullMesh => landmarks.length >= 468;
}
