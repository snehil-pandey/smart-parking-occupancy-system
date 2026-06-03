enum ActiveQrStatus { active, entryVerified, completed, expired, cancelled }

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
    required this.bookingStartAt,
    required this.bookingEndAt,
    this.entryScannedAt,
    this.exitScannedAt,
  });

  final String qrId;
  final String bookingId;
  final String userId;
  final String adminId;
  final String areaId;
  final ActiveQrStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime bookingStartAt;
  final DateTime bookingEndAt;
  final DateTime? entryScannedAt;
  final DateTime? exitScannedAt;

  DateTime get unlockAt => bookingStartAt.subtract(const Duration(minutes: 5));

  bool isEntryUnlockedAt(DateTime now) =>
      !now.isBefore(unlockAt) &&
      now.isBefore(bookingEndAt) &&
      status == ActiveQrStatus.active;

  bool isExitUnlockedAt(DateTime now) =>
      now.isBefore(bookingEndAt) &&
      status == ActiveQrStatus.entryVerified &&
      exitScannedAt == null;

  bool isUnlockedAt(DateTime now) => isEntryUnlockedAt(now);

  ActiveQrTicket copyWith({
    String? qrId,
    String? bookingId,
    String? userId,
    String? adminId,
    String? areaId,
    ActiveQrStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? bookingStartAt,
    DateTime? bookingEndAt,
    DateTime? entryScannedAt,
    DateTime? exitScannedAt,
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
      bookingStartAt: bookingStartAt ?? this.bookingStartAt,
      bookingEndAt: bookingEndAt ?? this.bookingEndAt,
      entryScannedAt: entryScannedAt ?? this.entryScannedAt,
      exitScannedAt: exitScannedAt ?? this.exitScannedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'qrId': qrId,
    'bookingId': bookingId,
    'userId': userId,
    'adminId': adminId,
    'areaId': areaId,
    'status': status == ActiveQrStatus.entryVerified
        ? 'entry_verified'
        : status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'bookingStartAt': bookingStartAt.toIso8601String(),
    'bookingEndAt': bookingEndAt.toIso8601String(),
    'entryScannedAt': entryScannedAt?.toIso8601String(),
    'exitScannedAt': exitScannedAt?.toIso8601String(),
  };
}
