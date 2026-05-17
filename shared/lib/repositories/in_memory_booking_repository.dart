import '../models/booking.dart';
import '../utils/demo_seed.dart';
import 'booking_repository.dart';

class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository({List<Booking>? seed}) : _bookings = [...?seed] {
    if (_bookings.isEmpty) {
      _bookings.addAll(DemoSeed.bookings());
    }
  }

  final List<Booking> _bookings;

  @override
  Future<Booking?> activeForUser(String userId) async {
    return _bookings
        .where(
          (booking) =>
              booking.userId == userId &&
              booking.status == BookingStatus.active,
        )
        .firstOrNull;
  }

  @override
  Future<Booking> createBooking(Booking booking) async {
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<List<Booking>> getForAdmin(String adminId) async {
    return _bookings.where((booking) => booking.adminId == adminId).toList();
  }

  @override
  Future<List<Booking>> getForUser(String userId) async {
    return _bookings.where((booking) => booking.userId == userId).toList();
  }

  @override
  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) {
      return;
    }
    _bookings[index] = _bookings[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
  }
}
