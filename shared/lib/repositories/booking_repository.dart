import '../models/active_qr_ticket.dart';
import '../models/booking.dart';

abstract interface class BookingRepository {
  Future<List<Booking>> getForUser(String userId);

  Stream<List<Booking>> watchForUser(String userId, {int limit = 30});

  Future<List<Booking>> getForAdmin(String adminId);

  Stream<List<Booking>> watchForAdmin(String adminId, {int limit = 50});

  Future<Booking?> activeForUser(String userId);

  Future<Booking> createBooking(Booking booking);

  Future<ActiveQrTicket> createActiveQrTicket(Booking booking);

  Future<ActiveQrTicket?> getActiveQrForBooking(String bookingId);

  Stream<ActiveQrTicket?> watchActiveQrForBooking(String bookingId);

  Future<void> consumeQrTicket(String qrId);

  Future<Booking> cancelBooking({required String bookingId, String? reason});

  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  });
}
