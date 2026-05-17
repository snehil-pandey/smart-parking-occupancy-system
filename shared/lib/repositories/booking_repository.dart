import '../models/active_qr_ticket.dart';
import '../models/booking.dart';

abstract interface class BookingRepository {
  Future<List<Booking>> getForUser(String userId);

  Future<List<Booking>> getForAdmin(String adminId);

  Future<Booking?> activeForUser(String userId);

  Future<Booking> createBooking(Booking booking);

  Future<ActiveQrTicket> createActiveQrTicket(Booking booking);

  Future<ActiveQrTicket?> getActiveQrForBooking(String bookingId);

  Future<void> consumeQrTicket(String qrId);

  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  });
}
