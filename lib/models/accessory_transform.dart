/// Represents the computed transform for positioning an accessory overlay.
class AccessoryTransform {
  /// Center X position in image coordinates.
  final double x;

  /// Center Y position in image coordinates.
  final double y;

  /// Scale factor relative to reference size.
  final double scale;

  /// Rotation angle in radians.
  final double rotation;

  /// Width of the accessory after scaling.
  final double width;

  /// Height of the accessory after scaling.
  final double height;

  /// Opacity (0.0 - 1.0), used for depth-based fading.
  final double opacity;

  const AccessoryTransform({
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
    required this.width,
    required this.height,
    this.opacity = 1.0,
  });

  /// Identity transform (no change).
  static const AccessoryTransform identity = AccessoryTransform(
    x: 0,
    y: 0,
    scale: 1.0,
    rotation: 0.0,
    width: 0,
    height: 0,
  );

  /// Check if this transform is valid for rendering.
  bool get isValid => width > 0 && height > 0 && scale > 0;

  @override
  String toString() =>
      'AccessoryTransform(x: ${x.toStringAsFixed(1)}, y: ${y.toStringAsFixed(1)}, '
      'scale: ${scale.toStringAsFixed(2)}, rotation: ${rotation.toStringAsFixed(3)}, '
      'w: ${width.toStringAsFixed(0)}, h: ${height.toStringAsFixed(0)})';
}
