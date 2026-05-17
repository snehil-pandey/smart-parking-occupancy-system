import '../models/parking_review.dart';

abstract interface class ReviewRepository {
  Future<List<ParkingReview>> getForArea(String areaId, {int limit = 20});

  Stream<List<ParkingReview>> watchForArea(String areaId, {int limit = 20});

  Future<ParkingReview> upsertReview(ParkingReview review);
}
