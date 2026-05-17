import '../models/parking_review.dart';
import 'firebase_repository_exception.dart';
import 'review_repository.dart';

class FirebaseReviewRepository implements ReviewRepository {
  const FirebaseReviewRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'FirebaseReviewRepository needs cloud_firestore wiring. Query /reviews by areaId with limits.',
    );
  }

  @override
  Future<List<ParkingReview>> getForArea(
    String areaId, {
    int limit = 20,
  }) async => _missingConfig();

  @override
  Stream<List<ParkingReview>> watchForArea(String areaId, {int limit = 20}) =>
      _missingConfig();

  @override
  Future<ParkingReview> upsertReview(ParkingReview review) async =>
      _missingConfig();
}
