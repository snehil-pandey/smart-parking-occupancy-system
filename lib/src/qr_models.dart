import 'package:cloud_firestore/cloud_firestore.dart';

enum ActiveQrStatus { active, used, expired, cancelled }

enum BookingStatus {
  pending,
  active,
  confirmed,
  activeParking,
  completed,
  cancelled,
  expired,
}

enum QrScanStatus {
  valid,
  invalidQr,
  notFound,
  wrongLocation,
  alreadyUsed,
  expired,
  bookingNotFound,
  bookingNotActive,
  parkingActive,
  networkError,
  consumed,
}

class ParkingRegionSummary {
  const ParkingRegionSummary({required this.regionId, required this.name});

  final String regionId;
  final String name;

  factory ParkingRegionSummary.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ParkingRegionSummary(
      regionId: (data['regionId'] as String?) ?? doc.id,
      name: data['name'] as String? ?? doc.id,
    );
  }
}

class GatePointSummary {
  const GatePointSummary({
    required this.gateId,
    required this.name,
    required this.type,
  });

  final String gateId;
  final String name;
  final String type;

  factory GatePointSummary.fromJson(Map<String, Object?> json) {
    return GatePointSummary(
      gateId: json['gateId'] as String? ?? '',
      name: json['name'] as String? ?? 'Gate',
      type: json['type'] as String? ?? 'both',
    );
  }
}

class ScannerLocationContext {
  const ScannerLocationContext({
    required this.regionId,
    required this.regionName,
    required this.areaId,
    required this.areaName,
    required this.gateId,
    required this.gateName,
  });

  final String regionId;
  final String regionName;
  final String areaId;
  final String areaName;
  final String gateId;
  final String gateName;

  Map<String, String> toJson() => {
    'regionId': regionId,
    'regionName': regionName,
    'areaId': areaId,
    'areaName': areaName,
    'gateId': gateId,
    'gateName': gateName,
  };

  factory ScannerLocationContext.fromJson(Map<String, Object?> json) {
    return ScannerLocationContext(
      regionId: json['regionId'] as String? ?? '',
      regionName: json['regionName'] as String? ?? '',
      areaId: json['areaId'] as String? ?? '',
      areaName: json['areaName'] as String? ?? '',
      gateId: json['gateId'] as String? ?? '',
      gateName: json['gateName'] as String? ?? '',
    );
  }
}

class ActiveQrTicket {
  const ActiveQrTicket({
    required this.qrId,
    required this.bookingId,
    required this.status,
    required this.expiresAt,
    this.userId,
    this.adminId,
    this.areaId,
  });

  final String qrId;
  final String bookingId;
  final ActiveQrStatus status;
  final DateTime expiresAt;
  final String? userId;
  final String? adminId;
  final String? areaId;

  factory ActiveQrTicket.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ActiveQrTicket(
      qrId: (data['qrId'] as String?) ?? doc.id,
      bookingId: data['bookingId'] as String,
      status: _enumByName(
        ActiveQrStatus.values,
        data['status'] as String?,
        ActiveQrStatus.expired,
      ),
      expiresAt: _date(data['expiresAt']),
      userId: data['userId'] as String?,
      adminId: data['adminId'] as String?,
      areaId: data['areaId'] as String?,
    );
  }
}

class BookingSummary {
  const BookingSummary({
    required this.bookingId,
    required this.status,
    required this.parkingAreaId,
    required this.vehicleNumber,
    required this.endTime,
  });

  final String bookingId;
  final BookingStatus status;
  final String parkingAreaId;
  final String vehicleNumber;
  final DateTime endTime;

  factory BookingSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BookingSummary(
      bookingId: (data['bookingId'] as String?) ?? doc.id,
      status: _enumByName(
        BookingStatus.values,
        data['status'] as String?,
        BookingStatus.expired,
      ),
      parkingAreaId:
          (data['areaId'] ?? data['parkingLocationId'] ?? '') as String,
      vehicleNumber: data['vehicleNumber'] as String? ?? 'Not provided',
      endTime: _date(data['endTime']),
    );
  }

  bool get isGateValid =>
      status == BookingStatus.active || status == BookingStatus.confirmed;

  bool get isParkingActive => status == BookingStatus.activeParking;
}

class ParkingAreaSummary {
  const ParkingAreaSummary({
    required this.areaId,
    required this.regionId,
    required this.name,
    required this.gatePoints,
  });

  final String areaId;
  final String regionId;
  final String name;
  final List<GatePointSummary> gatePoints;

  factory ParkingAreaSummary.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final gates = (data['gatePoints'] as List<Object?>? ?? const [])
        .whereType<Map>()
        .map(
          (gate) => GatePointSummary.fromJson(
            gate.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((gate) => gate.gateId.isNotEmpty)
        .toList();
    return ParkingAreaSummary(
      areaId: (data['areaId'] as String?) ?? doc.id,
      regionId: data['regionId'] as String? ?? '',
      name: data['name'] as String? ?? doc.id,
      gatePoints: gates,
    );
  }
}

class QrScanResult {
  const QrScanResult({
    required this.status,
    required this.title,
    required this.message,
    required this.qrId,
    this.ticket,
    this.booking,
    this.parkingArea,
  });

  final QrScanStatus status;
  final String title;
  final String message;
  final String qrId;
  final ActiveQrTicket? ticket;
  final BookingSummary? booking;
  final ParkingAreaSummary? parkingArea;

  bool get canConfirm => status == QrScanStatus.valid;

  QrScanResult copyWith({
    QrScanStatus? status,
    String? title,
    String? message,
    ParkingAreaSummary? parkingArea,
  }) {
    return QrScanResult(
      status: status ?? this.status,
      title: title ?? this.title,
      message: message ?? this.message,
      qrId: qrId,
      ticket: ticket,
      booking: booking,
      parkingArea: parkingArea ?? this.parkingArea,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) {
    return fallback;
  }
  for (final value in values) {
    if (value.name == name || _snakeCase(value.name) == name) {
      return value;
    }
  }
  return fallback;
}

String _snakeCase(String value) {
  return value.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => '_${match.group(1)!.toLowerCase()}',
  );
}

DateTime _date(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  throw StateError('Missing Firestore timestamp.');
}
