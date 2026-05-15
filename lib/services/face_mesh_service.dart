import '../models/landmark.dart';

// Conditionally import the web or mobile implementation
import 'face_mesh_mobile.dart' if (dart.library.js_interop) 'face_mesh_web.dart';

/// Abstract service for detecting 468 face landmarks.
abstract class FaceMeshService {
  /// Initialize the underlying models
  Future<void> initialize();

  /// Detect face landmarks from a given image file.
  /// On Web, this may be a blob URL. On mobile, a local file path.
  Future<FaceData?> detect(String imagePath);

  /// Factory to get the correct platform implementation.
  factory FaceMeshService() => getFaceMeshService();
}
