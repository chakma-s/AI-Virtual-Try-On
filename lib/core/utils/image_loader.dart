import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ImageLoader {
  static Future<ui.Image> loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Completer<ui.Image> completer = Completer();
    
    ui.decodeImageFromList(data.buffer.asUint8List(), (ui.Image img) {
      return completer.complete(img);
    });
    
    return completer.future;
  }
}
