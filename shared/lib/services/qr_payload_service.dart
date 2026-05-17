import 'dart:convert';

import '../models/booking.dart';

class QrPayload {
  const QrPayload({
    required this.issuer,
    required this.bookingId,
    required this.userId,
    required this.parkingLocationId,
    required this.vehicleNumber,
    required this.startTime,
    required this.endTime,
    required this.version,
    required this.signature,
  });

  final String issuer;
  final String bookingId;
  final String userId;
  final String parkingLocationId;
  final String vehicleNumber;
  final DateTime startTime;
  final DateTime endTime;
  final int version;
  final String signature;
}

class QrPayloadService {
  const QrPayloadService({this.issuer = 'park_here'});

  final String issuer;

  String buildPayload({
    required String bookingId,
    required String userId,
    required String parkingLocationId,
    required String vehicleNumber,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final base = <String, Object?>{
      'issuer': issuer,
      'bookingId': bookingId,
      'userId': userId,
      'parkingLocationId': parkingLocationId,
      'vehicleNumber': vehicleNumber,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'version': 1,
    };
    final signature = _checksum(jsonEncode(base));
    return jsonEncode({...base, 'signature': signature});
  }

  bool canVerifyLocally(Booking booking) {
    final decoded = jsonDecode(booking.qrPayload) as Map<String, Object?>;
    final signature = decoded.remove('signature');
    return signature == _checksum(jsonEncode(decoded));
  }

  QrPayload parse(String payload) {
    final decoded = jsonDecode(payload) as Map<String, Object?>;
    return QrPayload(
      issuer: decoded['issuer'] as String,
      bookingId: decoded['bookingId'] as String,
      userId: decoded['userId'] as String,
      parkingLocationId: decoded['parkingLocationId'] as String,
      vehicleNumber: decoded['vehicleNumber'] as String,
      startTime: DateTime.parse(decoded['startTime'] as String),
      endTime: DateTime.parse(decoded['endTime'] as String),
      version: decoded['version'] as int,
      signature: decoded['signature'] as String,
    );
  }

  String _checksum(String input) {
    var hash = 17;
    for (final codeUnit in input.codeUnits) {
      hash = 37 * hash + codeUnit;
      hash = hash & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
