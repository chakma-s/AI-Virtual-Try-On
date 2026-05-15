import 'dart:math';

/// Utility class for 2D geometry calculations used in accessory placement.
class MathUtils {
  MathUtils._();

  /// Calculate Euclidean distance between two points.
  static double distance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }

  /// Calculate midpoint between two points.
  static (double, double) midpoint(
    double x1, double y1, double x2, double y2,
  ) {
    return ((x1 + x2) / 2, (y1 + y2) / 2);
  }

  /// Calculate angle (radians) between two points relative to horizontal.
  static double angleBetween(double x1, double y1, double x2, double y2) {
    return atan2(y2 - y1, x2 - x1);
  }

  /// Lerp between two values.
  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  /// Clamp value between min and max.
  static double clamp(double value, double minVal, double maxVal) {
    return max(minVal, min(maxVal, value));
  }

  /// Convert degrees to radians.
  static double degToRad(double degrees) => degrees * pi / 180.0;

  /// Convert radians to degrees.
  static double radToDeg(double radians) => radians * 180.0 / pi;
}
