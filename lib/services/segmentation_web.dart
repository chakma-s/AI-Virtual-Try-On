import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'segmentation_service.dart';

@JS('segmentItem')
external JSPromise _segmentItem(JSString imageDataUrl);

@JS('initSegmentation')
external JSPromise _initSegmentation();

class SegmentationServiceWeb implements SegmentationService {
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _initSegmentation().toDart;
      _initialized = true;
      return true;
    } catch (e) {
      print('Failed to init segmentation: $e');
      return false;
    }
  }

  @override
  Future<SegmentationResult?> segment(Uint8List imageBytes) async {
    try {
      // Convert bytes to data URL for JS
      final base64 = base64Encode(imageBytes);
      final dataUrl = 'data:image/png;base64,$base64';

      final result = await _segmentItem(dataUrl.toJS).toDart;
      if (result == null || result.isUndefinedOrNull) return null;

      final jsMask = js_util.getProperty(result, 'mask');
      final maskWidth = js_util.getProperty(result, 'maskWidth') as num;
      final maskHeight = js_util.getProperty(result, 'maskHeight') as num;
      final origWidth = js_util.getProperty(result, 'origWidth') as num;
      final origHeight = js_util.getProperty(result, 'origHeight') as num;

      // Convert JS array to Uint8List
      final int len = js_util.getProperty(jsMask, 'length') as int;
      final mask = Uint8List(len);
      for (int i = 0; i < len; i++) {
        mask[i] = (js_util.getProperty(jsMask, i.toString()) as num).toInt();
      }

      return SegmentationResult(
        mask: mask,
        maskWidth: maskWidth.toInt(),
        maskHeight: maskHeight.toInt(),
        originalWidth: origWidth.toInt(),
        originalHeight: origHeight.toInt(),
      );
    } catch (e) {
      print('Web segmentation error: $e');
      return null;
    }
  }
}

SegmentationService getSegmentationService() => SegmentationServiceWeb();
