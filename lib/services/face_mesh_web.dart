import 'dart:js_interop';
import 'dart:js_util' as js_util;
import '../models/landmark.dart';
import 'face_mesh_service.dart';

@JS('initFaceLandmarker')
external JSPromise _initFaceLandmarker();

@JS('detectFaces')
external JSPromise _detectFaces(JSString imageUrl);

/// Web implementation using MediaPipe Tasks Vision JS Library.
class FaceMeshServiceWeb implements FaceMeshService {
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _initFaceLandmarker().toDart;
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize MediaPipe JS: $e');
    }
  }

  @override
  Future<FaceData?> detect(String imagePath) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _detectFaces(imagePath.toJS).toDart;
      
      if (result == null || result.isUndefinedOrNull) {
        return null;
      }

      // The JS wrapper returns { landmarks: [...], width: num, height: num }
      final jsLandmarks = js_util.getProperty(result, 'landmarks');
      final width = js_util.getProperty(result, 'width') as num;
      final height = js_util.getProperty(result, 'height') as num;

      final List<FaceLandmark> landmarks = [];
      
      final int len = js_util.getProperty(jsLandmarks, 'length') as int;
      for (int i = 0; i < len; i++) {
        final pt = js_util.getProperty(jsLandmarks, i.toString());
        final x = js_util.getProperty(pt, 'x') as num;
        final y = js_util.getProperty(pt, 'y') as num;
        final z = js_util.getProperty(pt, 'z') as num;
        
        // MediaPipe Web returns normalized coordinates (0.0 to 1.0).
        // We convert them to pixel coordinates to match ML Kit's behavior.
        landmarks.add(FaceLandmark(
          x: x.toDouble() * width.toDouble(),
          y: y.toDouble() * height.toDouble(),
          z: z.toDouble() * width.toDouble(), // Z is roughly same scale as X
          index: i,
        ));
      }

      return FaceData(
        landmarks: landmarks,
        imageWidth: width.toInt(),
        imageHeight: height.toInt(),
      );
    } catch (e) {
      print('Error during JS face detection: $e');
      return null;
    }
  }
}

FaceMeshService getFaceMeshService() => FaceMeshServiceWeb();
