import 'dart:typed_data';
import '../core/constants.dart';

/// Represents a fashion accessory that can be virtually tried on.
class Accessory {
  final String id;
  final String name;
  final AccessoryCategory category;
  final String imagePath;       // Path to the PNG with transparency
  final String thumbnailPath;   // Path to catalog thumbnail
  final Uint8List? customImageBytes; // In-memory processed image
  final double offsetX;         // Horizontal offset fine-tuning
  final double offsetY;         // Vertical offset fine-tuning
  final double scaleAdjust;     // Per-item scale adjustment (1.0 = default)

  const Accessory({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    this.thumbnailPath = '',
    this.customImageBytes,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.scaleAdjust = 1.0,
  });

  /// Get the thumbnail path, defaulting to imagePath.
  String get displayImage => thumbnailPath.isNotEmpty ? thumbnailPath : imagePath;

  factory Accessory.fromJson(Map<String, dynamic> json) {
    return Accessory(
      id: json['id'] as String,
      name: json['name'] as String,
      category: AccessoryCategory.values.firstWhere(
        (c) => c.name == json['category'],
      ),
      imagePath: json['imagePath'] as String,
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
      scaleAdjust: (json['scaleAdjust'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'scaleAdjust': scaleAdjust,
    };
  }
}
