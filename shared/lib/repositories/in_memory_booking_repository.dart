import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import '../services/qr_payload_service.dart';
import '../utils/demo_seed.dart';
import 'booking_repository.dart';
import 'parking_repository.dart';

class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository({
    List<Booking>? seed,
    ParkingRepository? parkingRepository,
  }) : _bookings = [...?seed],
       _parkingRepository = parkingRepository {
    if (_bookings.isEmpty) {
      _bookings.addAll(DemoSeed.bookings());
    }
    for (final booking in _bookings.where(
      (booking) => booking.isAwaitingEntry,
    )) {
      _activeQrTickets.add(
        ActiveQrTicket(
          qrId: booking.qrId ?? const QrPayloadService().generateQrId(),
          bookingId: booking.id,
          userId: booking.userId,
          adminId: booking.adminId,
          areaId: booking.parkingLocationId,
          status: ActiveQrStatus.active,
          createdAt: booking.createdAt,
          expiresAt: booking.endTime,
          bookingStartAt: booking.startTime,
          bookingEndAt: booking.endTime,
          scannedOnce: false,
          scanPhase: 'entry_pending',
        ),
      );
    }
  }

  final List<Booking> _bookings;
  final List<ActiveQrTicket> _activeQrTickets = [];
  final ParkingRepository? _parkingRepository;

  @override
  Future<Booking?> activeForUser(String userId) async {
    return _bookings
        .where(
          (booking) => booking.userId == userId && booking.isCurrentSession,
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
    final qrId = booking.qrId ?? const QrPayloadService().generateQrId();
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
      bookingStartAt: booking.startTime,
      bookingEndAt: booking.endTime,
      scannedOnce: false,
      scanPhase: 'entry_pending',
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
    _activeQrTickets[index] = ticket.copyWith(
      status: ActiveQrStatus.used,
      scannedOnce: true,
      scanPhase: 'entered',
      entryScannedAt: now,
    );
    _replaceBookingById(
      ticket.bookingId,
      (booking) => booking.copyWith(
        status: BookingStatus.activeParking,
        entryVerified: true,
        entryScannedAt: now,
        qrUsedAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index == -1) {
      throw StateError('Booking $bookingId was not found.');
    }
    final booking = _bookings[index];
    if (booking.status == BookingStatus.cancelled) {
      return booking;
    }
    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.expired) {
      throw StateError('Booking $bookingId cannot be cancelled now.');
    }
    final now = DateTime.now();
    final inferredHourlyPrice =
        booking.price / booking.durationHours.clamp(1, 24);
    final fine = inferredHourlyPrice > 10 ? 10.0 : 0.0;
    final updated = booking.copyWith(
      status: BookingStatus.cancelled,
      cancellationFine: fine,
      cancelledAt: now,
      cancellationReason: reason?.trim().isEmpty == true
          ? null
          : reason?.trim(),
      refundAmount: (booking.price - fine).clamp(0, booking.price).toDouble(),
      updatedAt: now,
    );
    _bookings[index] = updated;
    await _parkingRepository?.releaseSlot(booking.parkingLocationId);
    final qrIndex = _activeQrTickets.indexWhere(
      (ticket) =>
          ticket.bookingId == bookingId &&
          ticket.status == ActiveQrStatus.active,
    );
    if (qrIndex != -1) {
      _activeQrTickets[qrIndex] = _activeQrTickets[qrIndex].copyWith(
        status: ActiveQrStatus.expired,
      );
    }
    return updated;
  }

  @override
  Future<List<Booking>> getForAdmin(String adminId) async {
    return _bookings.where((booking) => booking.adminId == adminId).toList();
  }

  @override
  Stream<List<Booking>> watchForAdmin(String adminId, {int limit = 50}) {
    return Stream.fromFuture(
      getForAdmin(adminId).then((bookings) => bookings.take(limit).toList()),
    );
  }

  @override
  Future<List<Booking>> getForUser(String userId) async {
    return _bookings.where((booking) => booking.userId == userId).toList();
  }

  @override
  Stream<List<Booking>> watchForUser(String userId, {int limit = 30}) {
    return Stream.fromFuture(
      getForUser(userId).then((bookings) => bookings.take(limit).toList()),
    );
  }

  @override
  Stream<ActiveQrTicket?> watchActiveQrForBooking(String bookingId) {
    return Stream.fromFuture(getActiveQrForBooking(bookingId));
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
