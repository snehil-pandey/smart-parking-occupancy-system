import 'package:park_here_shared/park_here_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active QR ticket uses status-only entry then exit lifecycle', () async {
    final repository = InMemoryBookingRepository();
    final now = DateTime.now();
    final qrId = const QrPayloadService().generateQrId();
    final booking = Booking(
      id: 'book_qr_test',
      userId: 'user_qr_test',
      adminId: 'admin_qr_test',
      parkingLocationId: 'area_qr_test',
      qrId: qrId,
      vehicleNumber: 'KA 06 TEST',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      price: 120,
      status: BookingStatus.confirmed,
      qrPayload: const QrPayloadService().buildPayload(qrId: qrId),
      createdAt: now,
      updatedAt: now,
    );

    await repository.createBooking(booking);
    final ticket = await repository.createActiveQrTicket(booking);

    expect(ticket.status, ActiveQrStatus.active);
    expect(ticket.bookingStartAt, booking.startTime);
    expect(ticket.bookingEndAt, booking.endTime);
    expect(await repository.getActiveQrForBooking(booking.id), isNotNull);

    await repository.consumeQrTicket(ticket.qrId);

    final enteredTicket = await repository.getActiveQrForBooking(booking.id);
    expect(enteredTicket, isNotNull);
    expect(enteredTicket!.status, ActiveQrStatus.entryVerified);
    final activeParking = (await repository.getForUser(booking.userId)).first;
    expect(activeParking.status, BookingStatus.activeParking);
    expect(activeParking.entryVerified, isTrue);
    expect(activeParking.entryScannedAt, isNotNull);
    expect(activeParking.qrUsedAt, isNull);

    await repository.consumeQrTicket(ticket.qrId);

    expect(await repository.getActiveQrForBooking(booking.id), isNull);
    final completed = (await repository.getForUser(booking.userId)).first;
    expect(completed.status, BookingStatus.completed);
    expect(completed.exitScannedAt, isNotNull);
  });

  test('QR payload contains only an opaque live QR id', () {
    const service = QrPayloadService();
    final qrId = service.generateQrId();
    final payload = service.buildPayload(qrId: qrId);

    expect(service.isOpaqueQrId(qrId), isTrue);
    expect(payload, qrId);
    expect(payload, isNot(contains('userId')));
    expect(payload, isNot(contains('vehicle')));
    expect(payload, isNot(contains('bookingId')));
  });

  test('QR is visible immediately while ticket status is active', () {
    final now = DateTime.now();
    final booking = _booking(
      id: 'book_unlock',
      now: now,
      startTime: now.add(const Duration(minutes: 20)),
      status: BookingStatus.confirmed,
    );
    final ticket = _ticket(
      booking: booking,
      createdAt: now,
      expiresAt: booking.endTime,
    );

    expect(booking.canShowEntryQr(ticket), isTrue);
  });

  test('QR remains visible for exit after entry verification', () {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 30));
    final booking =
        _booking(
          id: 'book_scanned',
          now: now,
          startTime: startTime,
          status: BookingStatus.activeParking,
        ).copyWith(
          entryVerified: true,
          entryScannedAt: now.subtract(const Duration(minutes: 20)),
        );
    final ticket =
        _ticket(
          booking: booking,
          createdAt: now,
          expiresAt: booking.endTime,
        ).copyWith(
          status: ActiveQrStatus.entryVerified,
          entryScannedAt: booking.entryScannedAt,
        );

    expect(booking.canShowEntryQr(ticket), isFalse);
    expect(booking.canShowExitQr(ticket), isTrue);
    expect(booking.isParkingActive, isTrue);
  });

  test('QR ids are unique and migration parser accepts old JSON', () {
    const service = QrPayloadService();
    final ids = List.generate(32, (_) => service.generateQrId()).toSet();

    expect(ids, hasLength(32));
    expect(ids.every(service.isOpaqueQrId), isTrue);

    final legacy = service.parse(
      '{"issuer":"park_here","bookingId":"book_old","qrId":"qr_book_old","version":1}',
    );
    expect(legacy.qrId, 'qr_book_old');
    expect(legacy.isLegacyJson, isTrue);
  });
}

Booking _booking({
  required String id,
  required DateTime now,
  required DateTime startTime,
  required BookingStatus status,
}) {
  final qrId = const QrPayloadService().generateQrId();
  return Booking(
    id: id,
    userId: 'user_qr_test',
    adminId: 'admin_qr_test',
    parkingLocationId: 'area_qr_test',
    qrId: qrId,
    vehicleNumber: 'KA 06 TEST',
    startTime: startTime,
    endTime: startTime.add(const Duration(hours: 2)),
    price: 120,
    status: status,
    qrPayload: const QrPayloadService().buildPayload(qrId: qrId),
    createdAt: now,
    updatedAt: now,
  );
}

ActiveQrTicket _ticket({
  required Booking booking,
  required DateTime createdAt,
  required DateTime expiresAt,
}) {
  return ActiveQrTicket(
    qrId: booking.qrId!,
    bookingId: booking.id,
    userId: booking.userId,
    adminId: booking.adminId,
    areaId: booking.parkingLocationId,
    status: ActiveQrStatus.active,
    createdAt: createdAt,
    expiresAt: expiresAt,
    bookingStartAt: booking.startTime,
    bookingEndAt: booking.endTime,
  );
}
