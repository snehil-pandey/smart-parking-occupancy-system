import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_scanner/src/qr_models.dart';
import 'package:park_here_scanner/src/qr_verification_service.dart';

void main() {
  const qrId = 'qr_live_abcdefghijklmnopqrstuvwxyz';
  final now = DateTime(2026, 5, 20, 12);
  final service = QrVerificationService();

  test('qrId format validation accepts only opaque Park Here ids', () {
    expect(service.isValidQrId(qrId), isTrue);
    expect(service.normalizeQrId('  $qrId  '), qrId);
    expect(service.isValidQrId('not-a-ticket'), isFalse);
    expect(
      service.isValidQrId('https://parkhere.example/ticket/$qrId'),
      isFalse,
    );
    expect(
      service.isValidQrId('{"qrId":"qr_live_abcdefghijklmnopqrstuvwxyz"}'),
      isFalse,
    );
  });

  test('invalid QR is rejected before Firebase trust', () {
    final result = service.evaluateResolved(qrId: 'not-a-ticket');

    expect(result.status, QrScanStatus.invalidQr);
    expect(result.canConfirm, isFalse);
  });

  test('expired QR is rejected', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(
        qrId: qrId,
        now: now,
        status: ActiveQrStatus.active,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      ),
      booking: _booking(now: now),
      now: now,
    );

    expect(result.status, QrScanStatus.expired);
    expect(result.canConfirm, isFalse);
  });

  test('used QR is rejected', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now, status: ActiveQrStatus.used),
      booking: _booking(now: now),
      now: now,
    );

    expect(result.status, QrScanStatus.alreadyUsed);
    expect(result.canConfirm, isFalse);
  });

  test('cancelled QR is rejected', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now, status: ActiveQrStatus.cancelled),
      booking: _booking(now: now),
      now: now,
    );

    expect(result.status, QrScanStatus.bookingNotActive);
    expect(result.canConfirm, isFalse);
  });

  test('active QR with active booking is accepted', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now),
      booking: _booking(now: now),
      now: now,
    );

    expect(result.status, QrScanStatus.valid);
    expect(result.canConfirm, isTrue);
  });

  test('active ticket-only precheck allows booking lookup to continue', () {
    final result = service.evaluateTicketOnly(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now),
      now: now,
    );

    expect(result, isNull);
  });

  test('active QR with inactive booking is rejected', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now),
      booking: _booking(now: now, status: BookingStatus.cancelled),
      now: now,
    );

    expect(result.status, QrScanStatus.bookingNotActive);
    expect(result.canConfirm, isFalse);
  });

  test('booking already in parking session is not entry-confirmable again', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now),
      booking: _booking(now: now, status: BookingStatus.activeParking),
      now: now,
    );

    expect(result.status, QrScanStatus.parkingActive);
    expect(result.canConfirm, isFalse);
  });

  test('wrong scanner location is rejected', () {
    final result = service.evaluateResolved(
      qrId: qrId,
      ticket: _ticket(qrId: qrId, now: now),
      booking: _booking(now: now, areaId: 'area_a'),
      scannerContext: const ScannerLocationContext(
        regionId: 'region_test',
        regionName: 'Test Region',
        areaId: 'area_b',
        areaName: 'Other Area',
        gateId: 'gate_1',
        gateName: 'Main Gate',
      ),
      now: now,
    );

    expect(result.status, QrScanStatus.wrongLocation);
    expect(result.canConfirm, isFalse);
  });
}

ActiveQrTicket _ticket({
  required String qrId,
  required DateTime now,
  ActiveQrStatus status = ActiveQrStatus.active,
  DateTime? expiresAt,
}) {
  return ActiveQrTicket(
    qrId: qrId,
    bookingId: 'booking_test',
    status: status,
    expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
    areaId: 'area_test',
  );
}

BookingSummary _booking({
  required DateTime now,
  BookingStatus status = BookingStatus.active,
  String areaId = 'area_test',
}) {
  return BookingSummary(
    bookingId: 'booking_test',
    status: status,
    parkingAreaId: areaId,
    vehicleNumber: 'KA 06 TEST',
    endTime: now.add(const Duration(hours: 1)),
  );
}
