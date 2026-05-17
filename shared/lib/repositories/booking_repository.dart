import '../models/booking.dart';

abstract interface class BookingRepository {
  Future<List<Booking>> getForUser(String userId);

  Future<List<Booking>> getForAdmin(String adminId);

  Future<Booking?> activeForUser(String userId);

  Future<Booking> createBooking(Booking booking);

  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  });
}
