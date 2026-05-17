import 'package:park_here_shared/park_here_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active QR ticket can be consumed only once', () async {
    final repository = InMemoryBookingRepository();
    final now = DateTime.now();
    final booking = Booking(
      id: 'book_qr_test',
      userId: 'user_qr_test',
      adminId: 'admin_qr_test',
      parkingLocationId: 'area_qr_test',
      qrId: 'qr_book_qr_test',
      vehicleNumber: 'KA 06 TEST',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      price: 120,
      status: BookingStatus.active,
      qrPayload: const QrPayloadService().buildPayload(
        bookingId: 'book_qr_test',
        qrId: 'qr_book_qr_test',
        userId: 'user_qr_test',
        parkingLocationId: 'area_qr_test',
        vehicleNumber: 'KA 06 TEST',
        startTime: now,
        endTime: now.add(const Duration(hours: 2)),
      ),
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
}
