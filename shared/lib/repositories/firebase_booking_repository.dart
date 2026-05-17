import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import 'booking_repository.dart';
import 'firebase_repository_exception.dart';

class FirebaseBookingRepository implements BookingRepository {
  const FirebaseBookingRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'Firebase packages/config are not wired in this local-first build. '
      'Add firebase_core, cloud_firestore, and Firebase initialization before using this repository.',
    );
  }

  @override
  Future<Booking?> activeForUser(String userId) async => _missingConfig();

  @override
  Future<Booking> createBooking(Booking booking) async => _missingConfig();

  @override
  Future<ActiveQrTicket> createActiveQrTicket(Booking booking) async =>
      _missingConfig();

  @override
  Future<ActiveQrTicket?> getActiveQrForBooking(String bookingId) async =>
      _missingConfig();

  @override
  Future<void> consumeQrTicket(String qrId) async => _missingConfig();

  @override
  Future<List<Booking>> getForAdmin(String adminId) async => _missingConfig();

  @override
  Future<List<Booking>> getForUser(String userId) async => _missingConfig();

  @override
  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  }) async => _missingConfig();
}
