import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'accessory.dart';

class DraggableItem {
  final String id;
  final Accessory accessory;
  final ui.Image image;
  Offset position;
  double scale;
  double rotation;
  bool autoSnapToFace;

  DraggableItem({
    String? id,
    required this.accessory,
    required this.image,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.autoSnapToFace = false,
  }) : id = id ?? const Uuid().v4();

  DraggableItem copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    bool? autoSnapToFace,
  }) {
    return DraggableItem(
      id: id,
      accessory: accessory,
      image: image,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      autoSnapToFace: autoSnapToFace ?? this.autoSnapToFace,
    );
  }
}
