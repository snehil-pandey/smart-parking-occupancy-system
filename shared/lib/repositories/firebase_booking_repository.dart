import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import '../services/qr_payload_service.dart';
import 'booking_repository.dart';

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Booking?> activeForUser(String userId) async {
    final snapshot = await _bookings.where('userId', isEqualTo: userId).get();
    return _sortedBookings(
      snapshot,
    ).where((booking) => booking.isCurrentSession).firstOrNull;
  }

  @override
  Future<Booking> createBooking(Booking booking) async {
    await _bookings
        .doc(booking.id)
        .set(
          FirestoreModelMapper.bookingToFirestore(booking),
          SetOptions(merge: true),
        );
    return booking;
  }

  @override
  Future<Booking> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final bookingRef = _bookings.doc(bookingId);
    return _firestore.runTransaction((transaction) async {
      final bookingDoc = await transaction.get(bookingRef);
      if (!bookingDoc.exists || bookingDoc.data() == null) {
        throw StateError('Booking $bookingId was not found.');
      }
      final booking = FirestoreModelMapper.bookingFromDoc(bookingDoc);
      if (booking.status == BookingStatus.cancelled) {
        return booking;
      }
      if (booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.expired) {
        throw StateError('Booking $bookingId cannot be cancelled now.');
      }

      final areaRef = _areas.doc(booking.parkingLocationId);
      final areaDoc = await transaction.get(areaRef);
      if (!areaDoc.exists || areaDoc.data() == null) {
        throw StateError(
          'Parking area ${booking.parkingLocationId} not found.',
        );
      }
      final activeQrDoc = booking.qrId == null
          ? null
          : await transaction.get(_activeQrTickets.doc(booking.qrId!));
      final area = FirestoreModelMapper.parkingAreaFromDoc(areaDoc);
      final now = DateTime.now();
      final fine = area.pricePerHour > 10 ? 10.0 : 0.0;
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

      transaction.update(bookingRef, {
        'status': BookingStatus.cancelled.name,
        'cancellationFine': fine,
        'cancelledAt': Timestamp.fromDate(now),
        'cancellationReason': updated.cancellationReason,
        'refundAmount': updated.refundAmount,
        'updatedAt': Timestamp.fromDate(now),
      });
      transaction.update(areaRef, {
        'availableSpaces': (area.availableSpaces + 1).clamp(
          0,
          area.totalSpaces,
        ),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (activeQrDoc != null &&
          activeQrDoc.exists &&
          activeQrDoc.data() != null) {
        final active = FirestoreModelMapper.activeQrFromDoc(activeQrDoc);
        if (_isOpenQrStatus(active.status)) {
          transaction.delete(_activeQrTickets.doc(active.qrId));
        }
      }
      return updated;
    });
  }

  @override
  Future<ActiveQrTicket> createActiveQrTicket(Booking booking) async {
    final qrId = booking.qrId ?? const QrPayloadService().generateQrId();
    final ticketRef = _activeQrTickets.doc(qrId);
    final bookingRef = _bookings.doc(booking.id);
    return _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ticketRef);
      if (existing.exists && existing.data() != null) {
        final ticket = FirestoreModelMapper.activeQrFromDoc(existing);
        if (ticket.status == ActiveQrStatus.active) {
          return ticket;
        }
        throw StateError('QR ticket $qrId has already been consumed.');
      }
      final now = DateTime.now();
      final ticket = ActiveQrTicket(
        qrId: qrId,
        bookingId: booking.id,
        userId: booking.userId,
        adminId: booking.adminId,
        areaId: booking.parkingLocationId,
        status: ActiveQrStatus.active,
        createdAt: now,
        expiresAt: booking.endTime,
        bookingStartAt: booking.startTime,
        bookingEndAt: booking.endTime,
      );
      transaction.set(
        ticketRef,
        FirestoreModelMapper.activeQrToFirestore(ticket),
      );
      transaction.set(
        bookingRef,
        FirestoreModelMapper.bookingToFirestore(
          booking.copyWith(qrId: qrId, updatedAt: now),
        ),
        SetOptions(merge: true),
      );
      return ticket;
    });
  }

  @override
  Future<ActiveQrTicket?> getActiveQrForBooking(String bookingId) async {
    final snapshot = await _activeQrTickets
        .where('bookingId', isEqualTo: bookingId)
        .get();
    final ticket = _activeTickets(
      snapshot,
    ).where((ticket) => _isOpenQrStatus(ticket.status)).firstOrNull;
    return ticket;
  }

  @override
  Stream<ActiveQrTicket?> watchActiveQrForBooking(String bookingId) {
    return _activeQrTickets
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map(
          (snapshot) => _activeTickets(
            snapshot,
          ).where((ticket) => _isOpenQrStatus(ticket.status)).firstOrNull,
        );
  }

  @override
  Future<void> consumeQrTicket(String qrId) async {
    final ticketRef = _activeQrTickets.doc(qrId);
    await _firestore.runTransaction((transaction) async {
      final ticketDoc = await transaction.get(ticketRef);
      if (!ticketDoc.exists || ticketDoc.data() == null) {
        throw StateError('QR ticket $qrId is not active.');
      }
      final ticket = FirestoreModelMapper.activeQrFromDoc(ticketDoc);
      if (!_isOpenQrStatus(ticket.status)) {
        throw StateError('QR ticket $qrId is not active.');
      }
      final now = DateTime.now();
      if (ticket.status == ActiveQrStatus.active) {
        transaction.update(ticketRef, {
          'status': 'entry_verified',
          'entryScannedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        transaction.update(_bookings.doc(ticket.bookingId), {
          'status': 'active_parking',
          'entryVerified': true,
          'entryScannedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      } else {
        transaction.delete(ticketRef);
        transaction.update(_bookings.doc(ticket.bookingId), {
          'status': BookingStatus.completed.name,
          'exitScannedAt': Timestamp.fromDate(now),
          'completedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    });
  }

  @override
  Future<List<Booking>> getForAdmin(String adminId) async {
    final snapshot = await _bookings
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map(FirestoreModelMapper.bookingFromDoc).toList();
  }

  @override
  Stream<List<Booking>> watchForAdmin(String adminId, {int limit = 50}) {
    return _bookings
        .where('adminId', isEqualTo: adminId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FirestoreModelMapper.bookingFromDoc).toList(),
        );
  }

  @override
  Future<List<Booking>> getForUser(String userId) async {
    final snapshot = await _bookings.where('userId', isEqualTo: userId).get();
    return _sortedBookings(snapshot).take(30).toList();
  }

  @override
  Stream<List<Booking>> watchForUser(String userId, {int limit = 30}) {
    return _bookings
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _sortedBookings(snapshot).take(limit).toList());
  }

  @override
  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': status == BookingStatus.activeParking
          ? 'active_parking'
          : status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    if (status == BookingStatus.completed ||
        status == BookingStatus.cancelled ||
        status == BookingStatus.expired) {
      final active = await _findActiveQrForBooking(bookingId);
      if (active == null) {
        return;
      }
      await _activeQrTickets.doc(active.qrId).delete();
    }
  }

  Future<ActiveQrTicket?> _findActiveQrForBooking(String bookingId) async {
    final snapshot = await _activeQrTickets
        .where('bookingId', isEqualTo: bookingId)
        .get();
    return _activeTickets(
      snapshot,
    ).where((ticket) => _isOpenQrStatus(ticket.status)).firstOrNull;
  }

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseCollectionPaths.bookings);

  CollectionReference<Map<String, dynamic>> get _activeQrTickets =>
      _firestore.collection(FirebaseCollectionPaths.activeQrTickets);

  CollectionReference<Map<String, dynamic>> get _areas =>
      _firestore.collection(FirebaseCollectionPaths.parkingAreas);

  List<Booking> _sortedBookings(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map(FirestoreModelMapper.bookingFromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ActiveQrTicket> _activeTickets(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(FirestoreModelMapper.activeQrFromDoc).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  bool _isOpenQrStatus(ActiveQrStatus status) =>
      status == ActiveQrStatus.active || status == ActiveQrStatus.entryVerified;
}
