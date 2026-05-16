import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'segmentation_service.dart';

@JS('segmentItem')
external JSPromise _segmentItem(JSString imageDataUrl);

class SegmentationServiceWeb implements SegmentationService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<SegmentationResult?> segment(Uint8List imageBytes) async {
    try {
      final b64 = base64Encode(imageBytes);
      final dataUrl = 'data:image/png;base64,$b64';

      final result = await _segmentItem(dataUrl.toJS).toDart;
      if (result == null || result.isUndefinedOrNull) return null;

      // Result is a base64 data URL string — extract bytes
      final resultUrl = (result as JSString).toDart;
      final commaIdx = resultUrl.indexOf(',');
      if (commaIdx < 0) return null;
      final pngBytes = base64Decode(resultUrl.substring(commaIdx + 1));

      return SegmentationResult(imageBytes: Uint8List.fromList(pngBytes));
    } catch (e) {
      print('Web segmentation error: $e');
      return null;
    }
  }
}

SegmentationService getSegmentationService() => SegmentationServiceWeb();
