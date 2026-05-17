class ParkingReview {
  const ParkingReview({
    required this.reviewId,
    required this.userId,
    required this.areaId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reviewId;
  final String userId;
  final String areaId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'reviewId': reviewId,
    'userId': userId,
    'areaId': areaId,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
