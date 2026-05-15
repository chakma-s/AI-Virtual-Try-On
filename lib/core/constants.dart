/// MediaPipe Face Mesh landmark indices used for accessory placement.
/// Reference: https://developers.google.com/mediapipe/solutions/vision/face_landmarker
class LandmarkIndices {
  LandmarkIndices._();

  // ─── Eye Landmarks (for glasses) ───
  static const int leftEyeOuter = 33;
  static const int leftEyeInner = 133;
  static const int rightEyeOuter = 263;
  static const int rightEyeInner = 362;
  static const int leftEyeTop = 159;
  static const int leftEyeBottom = 145;
  static const int rightEyeTop = 386;
  static const int rightEyeBottom = 374;

  // ─── Nose Landmarks (for glasses bridge) ───
  static const int noseBridge = 168;
  static const int noseTip = 1;
  static const int noseBottom = 2;

  // ─── Ear Landmarks (for earrings) ───
  static const int leftEarTop = 234;
  static const int leftEarBottom = 177;
  static const int rightEarTop = 454;
  static const int rightEarBottom = 401;
  static const int leftTragion = 93;
  static const int rightTragion = 323;

  // ─── Forehead / Head Landmarks (for hats) ───
  static const int foreheadTop = 10;
  static const int leftTemple = 67;
  static const int rightTemple = 297;
  static const int foreheadLeft = 54;
  static const int foreheadRight = 284;

  // ─── Jaw / Chin Landmarks (for necklaces) ───
  static const int chin = 152;
  static const int leftJaw = 172;
  static const int rightJaw = 397;
  static const int leftJawline = 136;
  static const int rightJawline = 365;

  // ─── Face Contour (for face shape analysis) ───
  static const List<int> faceOval = [
    10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288,
    397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
    172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109,
  ];
}

/// Category types for accessories.
enum AccessoryCategory {
  glasses('Glasses', '👓'),
  earrings('Earrings', '💎'),
  hats('Hats', '🎩'),
  necklaces('Necklaces', '📿');

  const AccessoryCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// Default multipliers for scaling accessories relative to face dimensions.
class ScaleMultipliers {
  ScaleMultipliers._();

  /// Glasses width = inter-pupillary distance × this value
  static const double glasses = 1.25;

  /// Earring scale relative to face width
  static const double earrings = 0.12;

  /// Hat width = temple-to-temple distance × this value
  static const double hats = 1.4;

  /// Necklace width = jaw width × this value
  static const double necklaces = 0.85;
}
