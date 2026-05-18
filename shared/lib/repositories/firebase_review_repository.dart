import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parking_review.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import 'review_repository.dart';

class FirebaseReviewRepository implements ReviewRepository {
  FirebaseReviewRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<ParkingReview>> getForArea(
    String areaId, {
    int limit = 20,
  }) async {
    final snapshot = await _reviews
        .where('areaId', isEqualTo: areaId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map(FirestoreModelMapper.reviewFromDoc).toList();
  }

  @override
  Stream<List<ParkingReview>> watchForArea(String areaId, {int limit = 20}) =>
      _reviews
          .where('areaId', isEqualTo: areaId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(FirestoreModelMapper.reviewFromDoc).toList(),
          );

  @override
  Future<ParkingReview> upsertReview(ParkingReview review) async =>
      _firestore.runTransaction((transaction) async {
        final areaRef = _firestore
            .collection(FirebaseCollectionPaths.parkingAreas)
            .doc(review.areaId);
        final reviewRef = _reviews.doc(review.reviewId);
        final areaSnapshot = await transaction.get(areaRef);
        final existingReview = await transaction.get(reviewRef);
        var ratingAverage = 0.0;
        var ratingCount = 0;
        if (areaSnapshot.exists && areaSnapshot.data() != null) {
          final data = areaSnapshot.data()!;
          ratingAverage = (data['ratingAverage'] as num? ?? 0).toDouble();
          ratingCount = data['ratingCount'] as int? ?? 0;
        }
        if (existingReview.exists && existingReview.data() != null) {
          final oldRating =
              (existingReview.data()!['rating'] as num? ?? review.rating)
                  .toDouble();
          final total = ratingAverage * ratingCount;
          if (ratingCount > 0) {
            ratingAverage = (total - oldRating + review.rating) / ratingCount;
          }
        } else {
          final total = ratingAverage * ratingCount;
          ratingCount += 1;
          ratingAverage = (total + review.rating) / ratingCount;
        }
        transaction.set(
          reviewRef,
          FirestoreModelMapper.reviewToFirestore(review),
          SetOptions(merge: true),
        );
        if (areaSnapshot.exists) {
          transaction.update(areaRef, {
            'ratingAverage': ratingAverage,
            'ratingCount': ratingCount,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
        return review;
      });

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection(FirebaseCollectionPaths.reviews);
}
