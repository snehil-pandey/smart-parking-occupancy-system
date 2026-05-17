import 'dart:typed_data';

import '../models/parking_area_image.dart';
import 'firebase_repository_exception.dart';
import 'image_repository.dart';

class FirebaseStorageImageRepository implements ImageRepository {
  const FirebaseStorageImageRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'Firebase Storage image mode is optional. Use this only after the Firebase '
      'project supports Storage billing/config, and keep FirestoreImageRepository '
      'available as the free-tier-friendly default.',
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
