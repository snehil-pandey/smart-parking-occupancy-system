import 'dart:convert';
import 'dart:math';

import '../models/booking.dart';

class QrPayload {
  const QrPayload({required this.qrId, required this.isLegacyJson});

  final String qrId;
  final bool isLegacyJson;
}

class QrPayloadService {
  const QrPayloadService({this.issuer = 'park_here'});

  final String issuer;

  String generateQrId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return 'qr_live_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  /// New QR privacy model: the rendered QR contains only the opaque live QR id.
  /// All sensitive booking/user/area fields stay in Firestore
  /// `/active_qr_tickets/{qrId}` and `/bookings/{bookingId}`.
  String buildPayload({required String qrId}) => qrId;

  bool isOpaqueQrId(String payload) =>
      RegExp(r'^qr_live_[A-Za-z0-9_-]{24,}$').hasMatch(payload);

  bool canVerifyLocally(Booking booking) {
    final parsed = parse(booking.qrPayload);
    return parsed.qrId.isNotEmpty;
  }

  QrPayload parse(String payload) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith('{')) {
      return QrPayload(qrId: trimmed, isLegacyJson: false);
    }
    try {
      final decoded = jsonDecode(trimmed) as Map<String, Object?>;
      return QrPayload(
        qrId: decoded['qrId'] as String? ?? '',
        isLegacyJson: true,
      );
    } on Object {
      return const QrPayload(qrId: '', isLegacyJson: true);
    }
  }
}
