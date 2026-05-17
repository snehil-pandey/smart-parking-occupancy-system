class Payment {
  const Payment({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.adminId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String userId;
  final String adminId;
  final double amount;
  final String status;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'paymentId': id,
    'bookingId': bookingId,
    'userId': userId,
    'adminId': adminId,
    'amount': amount,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };
}
