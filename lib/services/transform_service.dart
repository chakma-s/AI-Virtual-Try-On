
import '../core/constants.dart';
import '../core/utils/math_utils.dart';
import '../models/accessory.dart';
import '../models/accessory_transform.dart';
import '../models/landmark.dart';

/// Calculates the correct transform (position, scale, rotation) for placing
/// an accessory image on a detected face, based on landmark positions.
class TransformService {
  const TransformService();

  /// Main entry point: compute the transform for any accessory category.
  AccessoryTransform computeTransform({
    required FaceData face,
    required Accessory accessory,
    required double accessoryAspectRatio, // width / height of the PNG
  }) {
    switch (accessory.category) {
      case AccessoryCategory.glasses:
        return _computeGlassesTransform(face, accessory, accessoryAspectRatio);
      case AccessoryCategory.earrings:
        return _computeEarringsTransform(face, accessory, accessoryAspectRatio);
      case AccessoryCategory.hats:
        return _computeHatTransform(face, accessory, accessoryAspectRatio);
      case AccessoryCategory.necklaces:
        return _computeNecklaceTransform(face, accessory, accessoryAspectRatio);
    }
  }

  // ─── Glasses ───
  AccessoryTransform _computeGlassesTransform(
    FaceData face,
    Accessory accessory,
    double aspectRatio,
  ) {
    final leftEye = face[LandmarkIndices.leftEyeOuter];
    final rightEye = face[LandmarkIndices.rightEyeOuter];
    final noseBridge = face[LandmarkIndices.noseBridge];

    // Width based on eye-to-eye distance
    final eyeDistance = MathUtils.distance(
      leftEye.x, leftEye.y, rightEye.x, rightEye.y,
    );
    final width = eyeDistance * ScaleMultipliers.glasses * accessory.scaleAdjust;
    final height = width / aspectRatio;

    // Center between eyes, slightly above nose bridge
    final (cx, _) = MathUtils.midpoint(
      leftEye.x, leftEye.y, rightEye.x, rightEye.y,
    );

    // Rotation follows eye line
    final rotation = MathUtils.angleBetween(
      leftEye.x, leftEye.y, rightEye.x, rightEye.y,
    );

    return AccessoryTransform(
      x: cx + accessory.offsetX,
      y: noseBridge.y + accessory.offsetY,
      scale: width / eyeDistance,
      rotation: rotation,
      width: width,
      height: height,
    );
  }

  // ─── Earrings ───
  // Returns transform for LEFT earring. Call with mirrored accessory for RIGHT.
  AccessoryTransform _computeEarringsTransform(
    FaceData face,
    Accessory accessory,
    double aspectRatio,
  ) {
    final leftEar = face[LandmarkIndices.leftTragion];
    final rightEar = face[LandmarkIndices.rightTragion];
    final leftEyeOuter = face[LandmarkIndices.leftEyeOuter];
    final rightEyeOuter = face[LandmarkIndices.rightEyeOuter];

    // Face width for scale reference
    final faceWidth = MathUtils.distance(
      leftEyeOuter.x, leftEyeOuter.y,
      rightEyeOuter.x, rightEyeOuter.y,
    );

    final earringSize = faceWidth * ScaleMultipliers.earrings * accessory.scaleAdjust;
    final width = earringSize;
    final height = width / aspectRatio;

    // Rotation from face tilt
    final rotation = MathUtils.angleBetween(
      leftEar.x, leftEar.y, rightEar.x, rightEar.y,
    );

    // Position below the ear tragion point
    final earOffsetY = faceWidth * 0.15;

    return AccessoryTransform(
      x: leftEar.x + accessory.offsetX,
      y: leftEar.y + earOffsetY + accessory.offsetY,
      scale: earringSize / faceWidth,
      rotation: rotation,
      width: width,
      height: height,
    );
  }

  /// Get the right earring transform (mirrored).
  AccessoryTransform computeRightEarringTransform({
    required FaceData face,
    required Accessory accessory,
    required double accessoryAspectRatio,
  }) {
    final rightEar = face[LandmarkIndices.rightTragion];
    final leftEyeOuter = face[LandmarkIndices.leftEyeOuter];
    final rightEyeOuter = face[LandmarkIndices.rightEyeOuter];
    final leftEar = face[LandmarkIndices.leftTragion];

    final faceWidth = MathUtils.distance(
      leftEyeOuter.x, leftEyeOuter.y,
      rightEyeOuter.x, rightEyeOuter.y,
    );

    final earringSize = faceWidth * ScaleMultipliers.earrings * accessory.scaleAdjust;
    final width = earringSize;
    final height = width / accessoryAspectRatio;

    final rotation = MathUtils.angleBetween(
      leftEar.x, leftEar.y, rightEar.x, rightEar.y,
    );

    final earOffsetY = faceWidth * 0.15;

    return AccessoryTransform(
      x: rightEar.x - accessory.offsetX,
      y: rightEar.y + earOffsetY + accessory.offsetY,
      scale: earringSize / faceWidth,
      rotation: rotation,
      width: width,
      height: height,
    );
  }

  // ─── Hats ───
  AccessoryTransform _computeHatTransform(
    FaceData face,
    Accessory accessory,
    double aspectRatio,
  ) {
    final foreheadTop = face[LandmarkIndices.foreheadTop];
    final leftTemple = face[LandmarkIndices.leftTemple];
    final rightTemple = face[LandmarkIndices.rightTemple];

    // Width based on temple-to-temple distance
    final templeDistance = MathUtils.distance(
      leftTemple.x, leftTemple.y, rightTemple.x, rightTemple.y,
    );
    final width = templeDistance * ScaleMultipliers.hats * accessory.scaleAdjust;
    final height = width / aspectRatio;

    // Center horizontally between temples
    final (cx, _) = MathUtils.midpoint(
      leftTemple.x, leftTemple.y, rightTemple.x, rightTemple.y,
    );

    // Position above forehead (offset by hat height * factor)
    final hatY = foreheadTop.y - (height * 0.45);

    // Rotation follows temple line
    final rotation = MathUtils.angleBetween(
      leftTemple.x, leftTemple.y, rightTemple.x, rightTemple.y,
    );

    return AccessoryTransform(
      x: cx + accessory.offsetX,
      y: hatY + accessory.offsetY,
      scale: width / templeDistance,
      rotation: rotation,
      width: width,
      height: height,
    );
  }

  // ─── Necklaces ───
  AccessoryTransform _computeNecklaceTransform(
    FaceData face,
    Accessory accessory,
    double aspectRatio,
  ) {
    final chin = face[LandmarkIndices.chin];
    final leftJaw = face[LandmarkIndices.leftJaw];
    final rightJaw = face[LandmarkIndices.rightJaw];

    // Width based on jaw width
    final jawWidth = MathUtils.distance(
      leftJaw.x, leftJaw.y, rightJaw.x, rightJaw.y,
    );
    final width = jawWidth * ScaleMultipliers.necklaces * accessory.scaleAdjust;
    final height = width / aspectRatio;

    // Center below chin
    final (cx, _) = MathUtils.midpoint(
      leftJaw.x, leftJaw.y, rightJaw.x, rightJaw.y,
    );

    // Position below chin with offset
    final chinOffset = jawWidth * 0.2;

    // Rotation follows jawline
    final rotation = MathUtils.angleBetween(
      leftJaw.x, leftJaw.y, rightJaw.x, rightJaw.y,
    );

    return AccessoryTransform(
      x: cx + accessory.offsetX,
      y: chin.y + chinOffset + accessory.offsetY,
      scale: width / jawWidth,
      rotation: rotation,
      width: width,
      height: height,
    );
  }
}
