import '../models/landmark.dart';
import 'face_mesh_service.dart';

/// Mobile (Android/iOS) implementation using Google ML Kit.
class FaceMeshServiceMobile implements FaceMeshService {
  @override
  Future<void> initialize() async {
    // ML Kit models are downloaded automatically on first use or bundled
  }

  @override
  Future<FaceData?> detect(String imagePath) async {
    // TODO: Implement ML Kit Face Detection for mobile later
    print('Mobile ML Kit Face Detection not fully implemented yet.');
    return null;
  }
}

FaceMeshService getFaceMeshService() => FaceMeshServiceMobile();
