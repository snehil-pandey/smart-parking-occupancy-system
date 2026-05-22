enum ActiveQrStatus { active, used, expired, cancelled }

class ActiveQrTicket {
  const ActiveQrTicket({
    required this.qrId,
    required this.bookingId,
    required this.userId,
    required this.adminId,
    required this.areaId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  final String qrId;
  final String bookingId;
  final String userId;
  final String adminId;
  final String areaId;
  final ActiveQrStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  ActiveQrTicket copyWith({
    String? qrId,
    String? bookingId,
    String? userId,
    String? adminId,
    String? areaId,
    ActiveQrStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return ActiveQrTicket(
      qrId: qrId ?? this.qrId,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      adminId: adminId ?? this.adminId,
      areaId: areaId ?? this.areaId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, Object?> toJson() => {
    'qrId': qrId,
    'bookingId': bookingId,
    'userId': userId,
    'adminId': adminId,
    'areaId': areaId,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };
}
