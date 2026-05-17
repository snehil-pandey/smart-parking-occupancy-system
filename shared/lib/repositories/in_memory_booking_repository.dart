import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import '../utils/demo_seed.dart';
import 'booking_repository.dart';

class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository({List<Booking>? seed}) : _bookings = [...?seed] {
    if (_bookings.isEmpty) {
      _bookings.addAll(DemoSeed.bookings());
    }
    for (final booking in _bookings.where(
      (booking) => booking.status == BookingStatus.active,
    )) {
      _activeQrTickets.add(
        ActiveQrTicket(
          qrId: booking.qrId ?? 'qr_${booking.id}',
          bookingId: booking.id,
          userId: booking.userId,
          adminId: booking.adminId,
          areaId: booking.parkingLocationId,
          status: ActiveQrStatus.active,
          createdAt: booking.createdAt,
          expiresAt: booking.endTime,
        ),
      );
    }
  }

  final List<Booking> _bookings;
  final List<ActiveQrTicket> _activeQrTickets = [];

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
  Future<ActiveQrTicket> createActiveQrTicket(Booking booking) async {
    final qrId = booking.qrId ?? 'qr_${booking.id}';
    final existing = _activeQrTickets.where((ticket) => ticket.qrId == qrId);
    if (existing.isNotEmpty) {
      final ticket = existing.first;
      if (ticket.status == ActiveQrStatus.active) {
        return ticket;
      }
      throw StateError('QR ticket $qrId has already been consumed.');
    }
    final ticket = ActiveQrTicket(
      qrId: qrId,
      bookingId: booking.id,
      userId: booking.userId,
      adminId: booking.adminId,
      areaId: booking.parkingLocationId,
      status: ActiveQrStatus.active,
      createdAt: DateTime.now(),
      expiresAt: booking.endTime,
    );
    _activeQrTickets.insert(0, ticket);
    _replaceBooking(booking.copyWith(qrId: qrId, updatedAt: DateTime.now()));
    return ticket;
  }

  @override
  Future<ActiveQrTicket?> getActiveQrForBooking(String bookingId) async {
    final now = DateTime.now();
    final index = _activeQrTickets.indexWhere(
      (ticket) =>
          ticket.bookingId == bookingId &&
          ticket.status == ActiveQrStatus.active,
    );
    if (index == -1) {
      return null;
    }
    final ticket = _activeQrTickets[index];
    if (ticket.expiresAt.isBefore(now)) {
      _activeQrTickets[index] = ticket.copyWith(status: ActiveQrStatus.expired);
      await updateStatus(bookingId: bookingId, status: BookingStatus.expired);
      return null;
    }
    return ticket;
  }

  @override
  Future<void> consumeQrTicket(String qrId) async {
    final index = _activeQrTickets.indexWhere(
      (ticket) => ticket.qrId == qrId && ticket.status == ActiveQrStatus.active,
    );
    if (index == -1) {
      throw StateError('QR ticket $qrId is not active.');
    }
    final now = DateTime.now();
    final ticket = _activeQrTickets[index];
    _activeQrTickets[index] = ticket.copyWith(status: ActiveQrStatus.used);
    _replaceBookingById(
      ticket.bookingId,
      (booking) => booking.copyWith(
        status: BookingStatus.completed,
        qrUsedAt: now,
        updatedAt: now,
      ),
    );
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
    final qrIndex = _activeQrTickets.indexWhere(
      (ticket) =>
          ticket.bookingId == bookingId &&
          ticket.status == ActiveQrStatus.active,
    );
    if (qrIndex == -1) {
      return;
    }
    if (status == BookingStatus.completed) {
      _activeQrTickets[qrIndex] = _activeQrTickets[qrIndex].copyWith(
        status: ActiveQrStatus.used,
      );
    } else if (status == BookingStatus.cancelled ||
        status == BookingStatus.expired) {
      _activeQrTickets[qrIndex] = _activeQrTickets[qrIndex].copyWith(
        status: ActiveQrStatus.expired,
      );
    }
  }

  void _replaceBooking(Booking booking) {
    final index = _bookings.indexWhere((item) => item.id == booking.id);
    if (index == -1) {
      _bookings.insert(0, booking);
    } else {
      _bookings[index] = booking;
    }
  }

  void _replaceBookingById(
    String bookingId,
    Booking Function(Booking booking) update,
  ) {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) {
      return;
    }
    _bookings[index] = update(_bookings[index]);
  }
}
