import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import 'booking_repository.dart';
import 'firebase_repository_exception.dart';

class FirebaseBookingRepository implements BookingRepository {
  FirebaseBookingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Booking?> activeForUser(String userId) async {
    final snapshot = await _bookings
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: BookingStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    return snapshot.docs.firstOrNull == null
        ? null
        : FirestoreModelMapper.bookingFromDoc(snapshot.docs.first);
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
  Future<ActiveQrTicket> createActiveQrTicket(Booking booking) async {
    final qrId = booking.qrId ?? 'qr_${booking.id}';
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
        .where('status', isEqualTo: ActiveQrStatus.active.name)
        .orderBy('expiresAt')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    final ticket = FirestoreModelMapper.activeQrFromDoc(snapshot.docs.first);
    if (ticket.expiresAt.isBefore(DateTime.now())) {
      await updateStatus(bookingId: bookingId, status: BookingStatus.expired);
      await _activeQrTickets.doc(ticket.qrId).update({
        'status': ActiveQrStatus.expired.name,
      });
      return null;
    }
    return ticket;
  }

  @override
  Stream<ActiveQrTicket?> watchActiveQrForBooking(String bookingId) {
    return _activeQrTickets
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: ActiveQrStatus.active.name)
        .orderBy('expiresAt')
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : FirestoreModelMapper.activeQrFromDoc(snapshot.docs.first),
        )
        .handleError((Object error) {
          throw FirebaseRepositoryException(
            'Unable to watch active QR for booking $bookingId: $error',
          );
        });
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
      if (ticket.status != ActiveQrStatus.active) {
        throw StateError('QR ticket $qrId is not active.');
      }
      final now = DateTime.now();
      transaction.update(ticketRef, {'status': ActiveQrStatus.used.name});
      transaction.update(_bookings.doc(ticket.bookingId), {
        'status': BookingStatus.completed.name,
        'qrUsedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
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
        )
        .handleError((Object error) {
          throw FirebaseRepositoryException(
            'Unable to watch bookings for admin $adminId: $error',
          );
        });
  }

  @override
  Future<List<Booking>> getForUser(String userId) async {
    final snapshot = await _bookings
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();
    return snapshot.docs.map(FirestoreModelMapper.bookingFromDoc).toList();
  }

  @override
  Stream<List<Booking>> watchForUser(String userId, {int limit = 30}) {
    return _bookings
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(FirestoreModelMapper.bookingFromDoc).toList(),
        )
        .handleError((Object error) {
          throw FirebaseRepositoryException(
            'Unable to watch bookings for user $userId: $error',
          );
        });
  }

  @override
  Future<void> updateStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    await _bookings.doc(bookingId).update({
      'status': status.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    if (status == BookingStatus.completed ||
        status == BookingStatus.cancelled ||
        status == BookingStatus.expired) {
      final active = await _findActiveQrForBooking(bookingId);
      if (active == null) {
        return;
      }
      await _activeQrTickets.doc(active.qrId).update({
        'status': status == BookingStatus.completed
            ? ActiveQrStatus.used.name
            : ActiveQrStatus.expired.name,
      });
    }
  }

  Future<ActiveQrTicket?> _findActiveQrForBooking(String bookingId) async {
    final snapshot = await _activeQrTickets
        .where('bookingId', isEqualTo: bookingId)
        .where('status', isEqualTo: ActiveQrStatus.active.name)
        .orderBy('expiresAt')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return FirestoreModelMapper.activeQrFromDoc(snapshot.docs.first);
  }

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseCollectionPaths.bookings);

  CollectionReference<Map<String, dynamic>> get _activeQrTickets =>
      _firestore.collection(FirebaseCollectionPaths.activeQrTickets);
}
