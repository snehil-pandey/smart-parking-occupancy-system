import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'qr_models.dart';

class QrVerificationService {
  QrVerificationService({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static final RegExp qrIdPattern = RegExp(r'^qr_live_[A-Za-z0-9_-]{24,}$');

  final FirebaseFirestore? _firestore;

  String? normalizeQrId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return null;
    }
    if (!qrIdPattern.hasMatch(trimmed)) {
      return null;
    }
    return trimmed;
  }

  bool isValidQrId(String raw) => normalizeQrId(raw) != null;

  Future<QrScanResult> verify(
    String rawPayload, {
    ScannerLocationContext? scannerContext,
  }) async {
    final qrId = normalizeQrId(rawPayload);
    if (qrId == null) {
      return const QrScanResult(
        status: QrScanStatus.invalidQr,
        title: 'Invalid QR',
        message: 'Scan a current Park Here QR ticket.',
        qrId: '',
      );
    }

    try {
      debugPrint('Park Here Scanner: parsed qrId: $qrId');
      debugPrint('Park Here Scanner: Firestore lookup started for $qrId.');
      final ticketDoc = await _activeQrTickets.doc(qrId).get();
      if (!ticketDoc.exists || ticketDoc.data() == null) {
        debugPrint('Park Here Scanner: active QR ticket not found.');
        return QrScanResult(
          status: QrScanStatus.notFound,
          title: 'Invalid QR',
          message: 'Ticket was not found in Firebase.',
          qrId: qrId,
        );
      }

      final ticket = ActiveQrTicket.fromDoc(ticketDoc);
      final earlyResult = evaluateTicketOnly(qrId: qrId, ticket: ticket);
      if (earlyResult != null) {
        return earlyResult;
      }

      debugPrint(
        'Park Here Scanner: reading booking ${ticket.bookingId} for QR $qrId.',
      );
      final bookingDoc = await _bookings.doc(ticket.bookingId).get();
      final booking = bookingDoc.exists && bookingDoc.data() != null
          ? BookingSummary.fromDoc(bookingDoc)
          : null;
      debugPrint(
        booking == null
            ? 'Park Here Scanner: booking not found.'
            : 'Park Here Scanner: booking found with status ${booking.status.name}.',
      );
      final areaId = ticket.areaId ?? booking?.parkingAreaId;
      final areaDoc = areaId == null || areaId.isEmpty
          ? null
          : await _parkingAreas.doc(areaId).get();
      final area = areaDoc != null && areaDoc.exists && areaDoc.data() != null
          ? ParkingAreaSummary.fromDoc(areaDoc)
          : null;
      debugPrint(
        area == null
            ? 'Park Here Scanner: parking area not found or not needed.'
            : 'Park Here Scanner: parking area found: ${area.name}.',
      );

      return evaluateResolved(
        qrId: qrId,
        ticket: ticket,
        booking: booking,
        parkingArea: area,
        scannerContext: scannerContext,
      );
    } on FirebaseException catch (error) {
      return _networkError(qrId, error.message);
    } on Object catch (error) {
      return _networkError(qrId, error.toString());
    }
  }

  QrScanResult? evaluateTicketOnly({
    required String qrId,
    required ActiveQrTicket ticket,
    DateTime? now,
  }) {
    if (ticket.status == ActiveQrStatus.used) {
      return _rejected(
        status: QrScanStatus.alreadyUsed,
        title: 'Already Used',
        message: 'This ticket has already been used.',
        qrId: qrId,
        ticket: ticket,
      );
    }
    if (ticket.status == ActiveQrStatus.cancelled) {
      return _rejected(
        status: QrScanStatus.bookingNotActive,
        title: 'Cancelled Ticket',
        message: 'This ticket was cancelled and cannot be used.',
        qrId: qrId,
        ticket: ticket,
      );
    }
    if (ticket.status == ActiveQrStatus.expired ||
        !ticket.expiresAt.isAfter(now ?? DateTime.now())) {
      return _rejected(
        status: QrScanStatus.expired,
        title: 'Expired Ticket',
        message: 'This ticket is outside its validity window.',
        qrId: qrId,
        ticket: ticket,
      );
    }
    return null;
  }

  QrScanResult evaluateResolved({
    required String qrId,
    ActiveQrTicket? ticket,
    BookingSummary? booking,
    ParkingAreaSummary? parkingArea,
    ScannerLocationContext? scannerContext,
    DateTime? now,
  }) {
    if (!isValidQrId(qrId)) {
      return const QrScanResult(
        status: QrScanStatus.invalidQr,
        title: 'Invalid QR',
        message: 'Scan a current Park Here QR ticket.',
        qrId: '',
      );
    }
    if (ticket == null) {
      return QrScanResult(
        status: QrScanStatus.notFound,
        title: 'Invalid QR',
        message: 'Ticket was not found in Firebase.',
        qrId: qrId,
      );
    }
    final ticketOnlyResult = evaluateTicketOnly(
      qrId: qrId,
      ticket: ticket,
      now: now,
    );
    if (ticketOnlyResult != null) {
      return ticketOnlyResult;
    }
    if (booking == null) {
      return _rejected(
        status: QrScanStatus.bookingNotFound,
        title: 'Booking Not Found',
        message: 'The linked booking could not be found.',
        qrId: qrId,
        ticket: ticket,
      );
    }
    if (scannerContext != null &&
        scannerContext.areaId.isNotEmpty &&
        booking.parkingAreaId != scannerContext.areaId) {
      return QrScanResult(
        status: QrScanStatus.wrongLocation,
        title: 'Wrong Location',
        message: 'This QR belongs to another parking location.',
        qrId: qrId,
        ticket: ticket,
        booking: booking,
        parkingArea: parkingArea,
      );
    }
    if (booking.isParkingActive) {
      return QrScanResult(
        status: QrScanStatus.parkingActive,
        title: 'Parking Active',
        message: 'Entry has already been verified for this booking.',
        qrId: qrId,
        ticket: ticket,
        booking: booking,
        parkingArea: parkingArea,
      );
    }
    if (!booking.isGateValid) {
      return QrScanResult(
        status: QrScanStatus.bookingNotActive,
        title: 'Booking Not Active',
        message: 'The linked booking is not active or confirmed.',
        qrId: qrId,
        ticket: ticket,
        booking: booking,
      );
    }
    return QrScanResult(
      status: QrScanStatus.valid,
      title: 'Valid Ticket',
      message: 'Ticket is active and ready for entry.',
      qrId: qrId,
      ticket: ticket,
      booking: booking,
      parkingArea: parkingArea,
    );
  }

  Future<QrScanResult> consume(
    QrScanResult current, {
    ScannerLocationContext? scannerContext,
  }) async {
    final qrId = current.qrId;
    if (!current.canConfirm || qrId.isEmpty) {
      return current.copyWith(
        status: QrScanStatus.invalidQr,
        title: 'Invalid QR',
        message: 'Only a valid active ticket can be confirmed.',
      );
    }

    try {
      await _db.runTransaction((transaction) async {
        final ticketRef = _activeQrTickets.doc(qrId);
        final ticketDoc = await transaction.get(ticketRef);
        if (!ticketDoc.exists || ticketDoc.data() == null) {
          throw const QrConsumeException(
            status: QrScanStatus.notFound,
            title: 'Invalid QR',
            message: 'Ticket was not found.',
          );
        }

        final ticket = ActiveQrTicket.fromDoc(ticketDoc);
        if (ticket.status == ActiveQrStatus.used) {
          throw const QrConsumeException(
            status: QrScanStatus.alreadyUsed,
            title: 'Already Used',
            message: 'This ticket has already been used.',
          );
        }
        if (ticket.status == ActiveQrStatus.cancelled) {
          throw const QrConsumeException(
            status: QrScanStatus.bookingNotActive,
            title: 'Cancelled Ticket',
            message: 'This ticket was cancelled.',
          );
        }
        if (ticket.status != ActiveQrStatus.active ||
            !ticket.expiresAt.isAfter(DateTime.now())) {
          transaction.update(ticketRef, {
            'status': ActiveQrStatus.expired.name,
          });
          throw const QrConsumeException(
            status: QrScanStatus.expired,
            title: 'Expired Ticket',
            message: 'This ticket has expired.',
          );
        }

        final bookingRef = _bookings.doc(ticket.bookingId);
        final bookingDoc = await transaction.get(bookingRef);
        if (!bookingDoc.exists || bookingDoc.data() == null) {
          throw const QrConsumeException(
            status: QrScanStatus.bookingNotFound,
            title: 'Booking Not Found',
            message: 'The linked booking was not found.',
          );
        }

        final booking = BookingSummary.fromDoc(bookingDoc);
        if (booking.isParkingActive) {
          throw const QrConsumeException(
            status: QrScanStatus.parkingActive,
            title: 'Parking Active',
            message: 'Entry is already verified for this booking.',
          );
        }
        if (!booking.isGateValid) {
          throw const QrConsumeException(
            status: QrScanStatus.bookingNotActive,
            title: 'Booking Not Active',
            message: 'The linked booking is not active.',
          );
        }
        if (scannerContext != null &&
            scannerContext.areaId.isNotEmpty &&
            booking.parkingAreaId != scannerContext.areaId) {
          throw const QrConsumeException(
            status: QrScanStatus.wrongLocation,
            title: 'Wrong Location',
            message: 'This QR belongs to another parking location.',
          );
        }

        final now = FieldValue.serverTimestamp();
        transaction.update(ticketRef, {
          'status': ActiveQrStatus.used.name,
          'usedAt': now,
          'scannerMode': 'android_fallback',
          if (scannerContext != null) ...{
            'scannedAtAreaId': scannerContext.areaId,
            'scannedAtGateId': scannerContext.gateId,
          },
        });
        transaction.update(bookingRef, {
          'status': 'active_parking',
          'entryVerified': true,
          'entryScannedAt': now,
          'entryVerifiedAt': now,
          if (scannerContext != null) ...{
            'entryGateId': scannerContext.gateId,
            'entryScannerMode': 'android_fallback',
          },
          'qrUsedAt': now,
          'updatedAt': now,
        });
        transaction.set(_scanLogs.doc(), {
          'qrId': qrId,
          'bookingId': ticket.bookingId,
          'scannedAt': now,
          'result': QrScanStatus.consumed.name,
          'scannerMode': 'android_fallback',
          if (scannerContext != null) ...{
            'areaId': scannerContext.areaId,
            'gateId': scannerContext.gateId,
            'gateName': scannerContext.gateName,
          },
        });
      });

      return current.copyWith(
        status: QrScanStatus.consumed,
        title: 'Entry Confirmed',
        message: 'Parking is now active. This QR cannot be reused.',
      );
    } on QrConsumeException catch (error) {
      return current.copyWith(
        status: error.status,
        title: error.title,
        message: error.message,
      );
    } on FirebaseException catch (error) {
      return _networkError(qrId, error.message);
    } on Object catch (error) {
      return _networkError(qrId, error.toString());
    }
  }

  QrScanResult _rejected({
    required QrScanStatus status,
    required String title,
    required String message,
    required String qrId,
    ActiveQrTicket? ticket,
  }) {
    return QrScanResult(
      status: status,
      title: title,
      message: message,
      qrId: qrId,
      ticket: ticket,
    );
  }

  QrScanResult _networkError(String qrId, String? detail) {
    // Keep raw errors out of the UI while preserving enough text for debug logs.
    debugPrint('Park Here Scanner: Firebase error: $detail');
    return QrScanResult(
      status: QrScanStatus.networkError,
      title: 'Network Error',
      message: 'Unable to verify this ticket. Try again.',
      qrId: qrId,
    );
  }

  CollectionReference<Map<String, dynamic>> get _activeQrTickets =>
      _db.collection('active_qr_tickets');

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _parkingAreas =>
      _db.collection('parking_areas');

  CollectionReference<Map<String, dynamic>> get _scanLogs =>
      _db.collection('qr_scan_logs');

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
}

class QrConsumeException implements Exception {
  const QrConsumeException({
    required this.status,
    required this.title,
    required this.message,
  });

  final QrScanStatus status;
  final String title;
  final String message;
}
