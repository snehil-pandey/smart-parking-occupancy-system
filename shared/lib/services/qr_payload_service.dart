import 'dart:convert';

import '../models/booking.dart';

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

  String _checksum(String input) {
    var hash = 17;
    for (final codeUnit in input.codeUnits) {
      hash = 37 * hash + codeUnit;
      hash = hash & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
