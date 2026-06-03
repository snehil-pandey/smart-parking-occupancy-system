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
    required this.bookingStartAt,
    required this.bookingEndAt,
    this.scannedOnce = false,
    this.scanPhase = 'entry_pending',
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
  final bool scannedOnce;
  final String scanPhase;
  final DateTime? entryScannedAt;
  final DateTime? exitScannedAt;

  DateTime get unlockAt => bookingStartAt.subtract(const Duration(minutes: 5));

  DateTime get exitUnlockAt =>
      bookingEndAt.subtract(const Duration(minutes: 10));

  DateTime get exitClosesAt => bookingEndAt.add(const Duration(minutes: 10));

  bool isEntryUnlockedAt(DateTime now) =>
      !now.isBefore(unlockAt) &&
      now.isBefore(bookingEndAt) &&
      status == ActiveQrStatus.active &&
      !scannedOnce &&
      scanPhase == 'entry_pending';

  bool isExitUnlockedAt(DateTime now) =>
      !now.isBefore(exitUnlockAt) &&
      !now.isAfter(exitClosesAt) &&
      status == ActiveQrStatus.active &&
      scannedOnce &&
      entryScannedAt != null &&
      exitScannedAt == null &&
      scanPhase == 'entered';

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
    bool? scannedOnce,
    String? scanPhase,
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
      scannedOnce: scannedOnce ?? this.scannedOnce,
      scanPhase: scanPhase ?? this.scanPhase,
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
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'bookingStartAt': bookingStartAt.toIso8601String(),
    'bookingEndAt': bookingEndAt.toIso8601String(),
    'scannedOnce': scannedOnce,
    'scanPhase': scanPhase,
    'entryScannedAt': entryScannedAt?.toIso8601String(),
    'exitScannedAt': exitScannedAt?.toIso8601String(),
  };
}
