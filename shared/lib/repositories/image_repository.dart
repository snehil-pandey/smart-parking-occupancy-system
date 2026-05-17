import 'dart:typed_data';

import '../models/parking_area_image.dart';

abstract interface class ImageRepository {
  Future<List<ParkingAreaImage>> getThumbnailsForArea({
    required String areaId,
    int limit = 3,
    String? startAfterImageId,
  });

  Future<List<ParkingAreaImage>> getPreviewsForArea({
    required String areaId,
    int limit = 6,
    String? startAfterImageId,
  });

  Future<ParkingAreaImage?> findById(String imageId);

  Future<ParkingAreaImage> uploadOptimizedAreaImage({
    required String areaId,
    required String uploadedByAdminId,
    required Uint8List originalBytes,
  });

  Future<void> removeImage(String imageId);

  Future<ParkingAreaImage> replaceImage({
    required String imageId,
    required Uint8List originalBytes,
  });
}
