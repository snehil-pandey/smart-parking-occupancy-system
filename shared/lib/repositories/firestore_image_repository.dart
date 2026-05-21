import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parking_area_image.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import '../services/image_optimizer.dart';
import 'firebase_repository_exception.dart';
import 'image_repository.dart';

class FirestoreImageRepository implements ImageRepository {
  FirestoreImageRepository({
    FirebaseFirestore? firestore,
    ImageOptimizer optimizer = const ImageOptimizer(),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _optimizer = optimizer;

  final FirebaseFirestore _firestore;
  final ImageOptimizer _optimizer;

  @override
  Future<ParkingAreaImage?> findById(String imageId) async {
    final doc = await _images.doc(imageId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return FirestoreModelMapper.imageFromDoc(doc);
  }

  @override
  Future<List<ParkingAreaImage>> getPreviewsForArea({
    required String areaId,
    int limit = 6,
    String? startAfterImageId,
  }) async {
    return _getImagesForArea(
      areaId: areaId,
      limit: limit,
      startAfterImageId: startAfterImageId,
    );
  }

  @override
  Future<List<ParkingAreaImage>> getThumbnailsForArea({
    required String areaId,
    int limit = 3,
    String? startAfterImageId,
  }) async {
    return _getImagesForArea(
      areaId: areaId,
      limit: limit,
      startAfterImageId: startAfterImageId,
    );
  }

  @override
  Future<void> removeImage(String imageId) async {
    final image = await findById(imageId);
    await _images.doc(imageId).delete();
    if (image == null) {
      return;
    }
    await _removeImageRefs(image.areaId, imageId);
  }

  @override
  Future<ParkingAreaImage> replaceImage({
    required String imageId,
    required Uint8List originalBytes,
  }) async {
    final existing = await findById(imageId);
    if (existing == null) {
      throw FirebaseRepositoryException('Image $imageId was not found.');
    }
    final optimized = _optimizer.optimize(originalBytes);
    final updated = ParkingAreaImage(
      imageId: existing.imageId,
      areaId: existing.areaId,
      uploadedByAdminId: existing.uploadedByAdminId,
      thumbnailBase64: optimized.thumbnailBase64,
      previewBase64: optimized.previewBase64,
      mimeType: optimized.mimeType,
      uploadedAt: DateTime.now(),
    );
    await _images
        .doc(imageId)
        .set(
          FirestoreModelMapper.imageToFirestore(updated),
          SetOptions(merge: true),
        );
    return updated;
  }

  @override
  Future<ParkingAreaImage> uploadOptimizedAreaImage({
    required String areaId,
    required String uploadedByAdminId,
    required Uint8List originalBytes,
  }) async {
    final optimized = _optimizer.optimize(originalBytes);
    final imageId = 'img_${areaId}_${DateTime.now().millisecondsSinceEpoch}';
    final image = ParkingAreaImage(
      imageId: imageId,
      areaId: areaId,
      uploadedByAdminId: uploadedByAdminId,
      thumbnailBase64: optimized.thumbnailBase64,
      previewBase64: optimized.previewBase64,
      mimeType: optimized.mimeType,
      uploadedAt: DateTime.now(),
    );
    final areaRef = _firestore
        .collection(FirebaseCollectionPaths.parkingAreas)
        .doc(areaId);
    await _firestore.runTransaction((transaction) async {
      transaction.set(
        _images.doc(imageId),
        FirestoreModelMapper.imageToFirestore(image),
      );
      transaction.update(areaRef, {
        'thumbnailRefs': FieldValue.arrayUnion([imageId]),
        'imagePreviewRefs': FieldValue.arrayUnion([imageId]),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });
    return image;
  }

  Future<List<ParkingAreaImage>> _getImagesForArea({
    required String areaId,
    required int limit,
    String? startAfterImageId,
  }) async {
    final snapshot = await _images.where('areaId', isEqualTo: areaId).get();
    final images = snapshot.docs.map(FirestoreModelMapper.imageFromDoc).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    if (startAfterImageId == null) {
      return images.take(limit).toList();
    }
    final matchedIndex = images.indexWhere(
      (image) => image.imageId == startAfterImageId,
    );
    if (matchedIndex == -1) {
      return images.take(limit).toList();
    }
    final startIndex = matchedIndex + 1;
    return images.skip(startIndex).take(limit).toList();
  }

  Future<void> _removeImageRefs(String areaId, String imageId) async {
    await _firestore
        .collection(FirebaseCollectionPaths.parkingAreas)
        .doc(areaId)
        .update({
          'thumbnailRefs': FieldValue.arrayRemove([imageId]),
          'imagePreviewRefs': FieldValue.arrayRemove([imageId]),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  CollectionReference<Map<String, dynamic>> get _images =>
      _firestore.collection(FirebaseCollectionPaths.parkingAreaImages);
}
