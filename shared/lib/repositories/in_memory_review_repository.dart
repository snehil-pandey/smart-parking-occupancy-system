import '../models/parking_review.dart';
import '../utils/demo_seed.dart';
import 'review_repository.dart';

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({List<ParkingReview>? seed})
    : _reviews = [...?seed] {
    if (_reviews.isEmpty) {
      _reviews.addAll(DemoSeed.reviews());
    }
  }

  final List<ParkingReview> _reviews;

  @override
  Future<List<ParkingReview>> getForArea(
    String areaId, {
    int limit = 20,
  }) async {
    return _reviews
        .where((review) => review.areaId == areaId)
        .take(limit)
        .toList();
  }

  @override
  Stream<List<ParkingReview>> watchForArea(String areaId, {int limit = 20}) {
    return Stream.fromFuture(getForArea(areaId, limit: limit));
  }

  @override
  Future<ParkingReview> upsertReview(ParkingReview review) async {
    final index = _reviews.indexWhere(
      (item) => item.reviewId == review.reviewId,
    );
    if (index == -1) {
      _reviews.insert(0, review);
    } else {
      _reviews[index] = review;
    }
    return review;
  }
}
