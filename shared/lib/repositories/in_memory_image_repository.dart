import 'dart:typed_data';

import '../models/parking_area_image.dart';
import '../services/image_optimizer.dart';
import '../utils/demo_seed.dart';
import 'image_repository.dart';

class InMemoryImageRepository implements ImageRepository {
  InMemoryImageRepository({
    List<ParkingAreaImage>? seed,
    ImageOptimizer optimizer = const ImageOptimizer(),
  }) : _optimizer = optimizer,
       _images = [...?seed] {
    if (_images.isEmpty) {
      _images.addAll(DemoSeed.parkingAreaImages());
    }
  }

  final ImageOptimizer _optimizer;
  final List<ParkingAreaImage> _images;

  @override
  Future<ParkingAreaImage?> findById(String imageId) async {
    return _images.where((image) => image.imageId == imageId).firstOrNull;
  }

  @override
  Future<List<ParkingAreaImage>> getPreviewsForArea({
    required String areaId,
    int limit = 6,
    String? startAfterImageId,
  }) async {
    return _page(areaId, limit, startAfterImageId);
  }

  @override
  Future<List<ParkingAreaImage>> getThumbnailsForArea({
    required String areaId,
    int limit = 3,
    String? startAfterImageId,
  }) async {
    return _page(areaId, limit, startAfterImageId);
  }

  @override
  Future<void> removeImage(String imageId) async {
    _images.removeWhere((image) => image.imageId == imageId);
  }

  @override
  Future<ParkingAreaImage> replaceImage({
    required String imageId,
    required Uint8List originalBytes,
  }) async {
    final existing = await findById(imageId);
    if (existing == null) {
      throw StateError('Image $imageId not found.');
    }
    final optimized = _optimizer.optimize(originalBytes);
    final replacement = ParkingAreaImage(
      imageId: imageId,
      areaId: existing.areaId,
      uploadedByAdminId: existing.uploadedByAdminId,
      thumbnailBase64: optimized.thumbnailBase64,
      previewBase64: optimized.previewBase64,
      mimeType: optimized.mimeType,
      uploadedAt: DateTime.now(),
    );
    final index = _images.indexWhere((image) => image.imageId == imageId);
    _images[index] = replacement;
    return replacement;
  }

  @override
  Future<ParkingAreaImage> uploadOptimizedAreaImage({
    required String areaId,
    required String uploadedByAdminId,
    required Uint8List originalBytes,
  }) async {
    final optimized = _optimizer.optimize(originalBytes);
    final image = ParkingAreaImage(
      imageId: 'img_${DateTime.now().microsecondsSinceEpoch}',
      areaId: areaId,
      uploadedByAdminId: uploadedByAdminId,
      thumbnailBase64: optimized.thumbnailBase64,
      previewBase64: optimized.previewBase64,
      mimeType: optimized.mimeType,
      uploadedAt: DateTime.now(),
    );
    _images.insert(0, image);
    return image;
  }

  List<ParkingAreaImage> _page(
    String areaId,
    int limit,
    String? startAfterImageId,
  ) {
    final images = _images.where((image) => image.areaId == areaId).toList();
    final startIndex = startAfterImageId == null
        ? 0
        : images.indexWhere((image) => image.imageId == startAfterImageId) + 1;
    return images.skip(startIndex < 0 ? 0 : startIndex).take(limit).toList();
  }
}
