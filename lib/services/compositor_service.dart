import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/accessory_transform.dart';

/// Custom painter that renders an accessory image overlay
/// at the correct position, scale, and rotation on the camera preview.
class AccessoryOverlayPainter extends CustomPainter {
  final ui.Image accessoryImage;
  final AccessoryTransform transform;
  final bool mirrorHorizontally;

  AccessoryOverlayPainter({
    required this.accessoryImage,
    required this.transform,
    this.mirrorHorizontally = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!transform.isValid) return;

    canvas.save();

    // Mirror for front camera if needed
    if (mirrorHorizontally) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // Move to accessory center position
    canvas.translate(transform.x, transform.y);

    // Apply rotation around center
    canvas.rotate(transform.rotation);

    // Draw the accessory image centered at the transform position
    final srcRect = Rect.fromLTWH(
      0,
      0,
      accessoryImage.width.toDouble(),
      accessoryImage.height.toDouble(),
    );

    final dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: transform.width,
      height: transform.height,
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    canvas.drawImageRect(accessoryImage, srcRect, dstRect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AccessoryOverlayPainter oldDelegate) {
    return oldDelegate.transform.x != transform.x ||
        oldDelegate.transform.y != transform.y ||
        oldDelegate.transform.scale != transform.scale ||
        oldDelegate.transform.rotation != transform.rotation ||
        oldDelegate.accessoryImage != accessoryImage;
  }
}

/// Debug painter that shows detected face landmarks as dots.
class LandmarkDebugPainter extends CustomPainter {
  final List<Offset> landmarks;
  final Color dotColor;
  final double dotRadius;

  LandmarkDebugPainter({
    required this.landmarks,
    this.dotColor = Colors.cyan,
    this.dotRadius = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    for (final point in landmarks) {
      canvas.drawCircle(point, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkDebugPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks;
  }
}
