enum BookingStatus { pending, active, completed, cancelled, expired }

class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.adminId,
    required this.parkingLocationId,
    this.qrId,
    this.qrUsedAt,
    required this.vehicleNumber,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.status,
    required this.qrPayload,
    required this.createdAt,
    required this.updatedAt,
    this.cancellationFine = 0,
    this.cancelledAt,
    this.cancellationReason,
    this.refundAmount,
  });

  final String id;
  final String userId;
  final String adminId;
  final String parkingLocationId;
  final String? qrId;
  final DateTime? qrUsedAt;
  final String vehicleNumber;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final BookingStatus status;
  final String qrPayload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double cancellationFine;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final double? refundAmount;

  int get durationHours => endTime.difference(startTime).inHours;

  Booking copyWith({
    String? id,
    String? userId,
    String? adminId,
    String? parkingLocationId,
    String? qrId,
    DateTime? qrUsedAt,
    String? vehicleNumber,
    DateTime? startTime,
    DateTime? endTime,
    double? price,
    BookingStatus? status,
    String? qrPayload,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? cancellationFine,
    DateTime? cancelledAt,
    String? cancellationReason,
    double? refundAmount,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      adminId: adminId ?? this.adminId,
      parkingLocationId: parkingLocationId ?? this.parkingLocationId,
      qrId: qrId ?? this.qrId,
      qrUsedAt: qrUsedAt ?? this.qrUsedAt,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      price: price ?? this.price,
      status: status ?? this.status,
      qrPayload: qrPayload ?? this.qrPayload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancellationFine: cancellationFine ?? this.cancellationFine,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      refundAmount: refundAmount ?? this.refundAmount,
    );
  }

  Map<String, Object?> toJson() => {
    'bookingId': id,
    'userId': userId,
    'adminId': adminId,
    'parkingLocationId': parkingLocationId,
    'areaId': parkingLocationId,
    'qrId': qrId,
    'qrUsedAt': qrUsedAt?.toIso8601String(),
    'vehicleNumber': vehicleNumber,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'price': price,
    'status': status.name,
    'qrPayload': qrPayload,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'cancellationFine': cancellationFine,
    'cancelledAt': cancelledAt?.toIso8601String(),
    'cancellationReason': cancellationReason,
    'refundAmount': refundAmount,
  };
}
