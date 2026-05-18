import 'package:park_here_shared/park_here_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active QR ticket can be consumed only once', () async {
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
      status: BookingStatus.active,
      qrPayload: const QrPayloadService().buildPayload(qrId: qrId),
      createdAt: now,
      updatedAt: now,
    );

    await repository.createBooking(booking);
    final ticket = await repository.createActiveQrTicket(booking);

    expect(ticket.status, ActiveQrStatus.active);
    expect(await repository.getActiveQrForBooking(booking.id), isNotNull);

    await repository.consumeQrTicket(ticket.qrId);

    expect(await repository.getActiveQrForBooking(booking.id), isNull);
    final completed = (await repository.getForUser(booking.userId)).first;
    expect(completed.status, BookingStatus.completed);
    expect(completed.qrUsedAt, isNotNull);
    expect(
      () => repository.consumeQrTicket(ticket.qrId),
      throwsA(isA<StateError>()),
    );
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
