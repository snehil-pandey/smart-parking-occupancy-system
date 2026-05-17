import 'dart:typed_data';

import '../models/parking_area_image.dart';
import 'firebase_repository_exception.dart';
import 'image_repository.dart';

class FirestoreImageRepository implements ImageRepository {
  const FirestoreImageRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'Firestore image mode is the default architecture, but cloud_firestore '
      'is not wired in this local-first build yet. Store optimized image '
      'documents in /parking_area_images when Firebase is enabled.',
    );
  }

  @override
  Future<ParkingAreaImage?> findById(String imageId) async => _missingConfig();

  @override
  Future<List<ParkingAreaImage>> getPreviewsForArea({
    required String areaId,
    int limit = 6,
    String? startAfterImageId,
  }) async => _missingConfig();

  @override
  Future<List<ParkingAreaImage>> getThumbnailsForArea({
    required String areaId,
    int limit = 3,
    String? startAfterImageId,
  }) async => _missingConfig();

  @override
  Future<void> removeImage(String imageId) async => _missingConfig();

  @override
  Future<ParkingAreaImage> replaceImage({
    required String imageId,
    required Uint8List originalBytes,
  }) async => _missingConfig();

  @override
  Future<ParkingAreaImage> uploadOptimizedAreaImage({
    required String areaId,
    required String uploadedByAdminId,
    required Uint8List originalBytes,
  }) async => _missingConfig();
}
