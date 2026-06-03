import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/active_qr_ticket.dart';
import '../models/booking.dart';
import '../models/geo_point.dart';
import '../models/issue_report.dart';
import '../models/parking_area_image.dart';
import '../models/parking_location.dart';
import '../models/parking_region.dart';
import '../models/parking_review.dart';

class FirestoreModelMapper {
  const FirestoreModelMapper._();

  static const _dateKeys = {
    'createdAt',
    'updatedAt',
    'uploadedAt',
    'startTime',
    'bookingStartAt',
    'endTime',
    'bookingEndAt',
    'expiresAt',
    'qrUsedAt',
    'entryScannedAt',
    'exitScannedAt',
    'usedAt',
    'completedAt',
    'expiredAt',
    'cancelledAt',
  };

  static Map<String, Object?> toFirestore(Map<String, Object?> json) {
    return json.map((key, value) {
      if (value == null) {
        return MapEntry(key, null);
      }
      if (_dateKeys.contains(key) && value is String && value.isNotEmpty) {
        return MapEntry(key, Timestamp.fromDate(DateTime.parse(value)));
      }
      return MapEntry(key, value);
    });
  }

  static Map<String, Object?> fromFirestore(
    Map<String, Object?> json, {
    String? documentId,
  }) {
    final mapped = json.map((key, value) {
      return MapEntry(key, _fromFirestoreValue(value));
    });
    if (documentId != null) {
      mapped.putIfAbsent('id', () => documentId);
      mapped.putIfAbsent('areaId', () => documentId);
      mapped.putIfAbsent('bookingId', () => documentId);
      mapped.putIfAbsent('imageId', () => documentId);
      mapped.putIfAbsent('issueId', () => documentId);
      mapped.putIfAbsent('reviewId', () => documentId);
      mapped.putIfAbsent('regionId', () => documentId);
      mapped.putIfAbsent('qrId', () => documentId);
    }
    return mapped;
  }

  static Object? _fromFirestoreValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is List) {
      return value.map(_fromFirestoreValue).toList();
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(
          key.toString(),
          _fromFirestoreValue(nestedValue as Object?),
        ),
      );
    }
    return value;
  }

  static ParkingLocation parkingAreaFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = fromFirestore(doc.data()!, documentId: doc.id);
    json.putIfAbsent(
      'vehicleTypes',
      () => json['supportedVehicleTypes'] ?? const <String>[],
    );
    return ParkingLocation.fromJson(json);
  }

  static ParkingRegion regionFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ParkingRegion.fromJson(
      fromFirestore(doc.data()!, documentId: doc.id),
    );
  }

  static ParkingAreaImage imageFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ParkingAreaImage.fromJson(
      fromFirestore(doc.data()!, documentId: doc.id),
    );
  }

  static Booking bookingFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = fromFirestore(doc.data()!, documentId: doc.id);
    return Booking(
      id: (json['bookingId'] ?? json['id']) as String,
      userId: json['userId'] as String,
      adminId: json['adminId'] as String,
      parkingLocationId:
          (json['areaId'] ?? json['parkingLocationId']) as String,
      qrId: json['qrId'] as String?,
      qrUsedAt: _nullableDate(json['qrUsedAt']),
      entryVerified: json['entryVerified'] as bool? ?? false,
      entryScannedAt: _nullableDate(json['entryScannedAt']),
      exitScannedAt: _nullableDate(json['exitScannedAt']),
      vehicleNumber: json['vehicleNumber'] as String,
      startTime: _requiredDate(json['bookingStartAt'] ?? json['startTime']),
      endTime: _requiredDate(json['bookingEndAt'] ?? json['endTime']),
      price: (json['price'] as num).toDouble(),
      status: _enumByName(
        BookingStatus.values,
        json['status'] as String,
        BookingStatus.expired,
      ),
      qrPayload: json['qrPayload'] as String,
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
      cancellationFine: (json['cancellationFine'] as num? ?? 0).toDouble(),
      cancelledAt: _nullableDate(json['cancelledAt']),
      cancellationReason: json['cancellationReason'] as String?,
      refundAmount: (json['refundAmount'] as num?)?.toDouble(),
    );
  }

  static ActiveQrTicket activeQrFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = fromFirestore(doc.data()!, documentId: doc.id);
    return ActiveQrTicket(
      qrId: json['qrId'] as String,
      bookingId: json['bookingId'] as String,
      userId: json['userId'] as String,
      adminId: json['adminId'] as String,
      areaId: json['areaId'] as String,
      status: _enumByName(
        ActiveQrStatus.values,
        json['status'] as String,
        ActiveQrStatus.expired,
      ),
      createdAt: _requiredDate(json['createdAt']),
      expiresAt: _requiredDate(json['expiresAt']),
      bookingStartAt: _requiredDate(
        json['bookingStartAt'] ?? json['createdAt'],
      ),
      bookingEndAt: _requiredDate(json['bookingEndAt'] ?? json['expiresAt']),
      entryScannedAt: _nullableDate(json['entryScannedAt']),
      exitScannedAt: _nullableDate(json['exitScannedAt']),
    );
  }

  static ParkingReview reviewFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = fromFirestore(doc.data()!, documentId: doc.id);
    return ParkingReview(
      reviewId: json['reviewId'] as String,
      userId: json['userId'] as String,
      areaId: json['areaId'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String,
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }

  static IssueReport issueFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final json = fromFirestore(doc.data()!, documentId: doc.id);
    return IssueReport(
      issueId: json['issueId'] as String,
      userId: json['userId'] as String,
      areaId: json['areaId'] as String,
      adminId: json['adminId'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      status: _issueStatus(json['status'] as String),
      createdAt: _requiredDate(json['createdAt']),
      updatedAt: _requiredDate(json['updatedAt']),
    );
  }

  static Map<String, Object?> regionToFirestore(ParkingRegion region) =>
      toFirestore(region.toJson());

  static Map<String, Object?> parkingAreaToFirestore(ParkingLocation area) =>
      toFirestore({
        ...area.toJson(),
        'supportedVehicleTypes': area.vehicleTypes
            .map((type) => type.name)
            .toList(),
      });

  static Map<String, Object?> bookingToFirestore(Booking booking) =>
      toFirestore(booking.toJson());

  static Map<String, Object?> activeQrToFirestore(ActiveQrTicket ticket) =>
      toFirestore(ticket.toJson());

  static Map<String, Object?> imageToFirestore(ParkingAreaImage image) =>
      toFirestore(image.toJson());

  static Map<String, Object?> reviewToFirestore(ParkingReview review) =>
      toFirestore(review.toJson());

  static Map<String, Object?> issueToFirestore(IssueReport issue) =>
      toFirestore(issue.toJson());

  static List<GeoPointValue> geoPointsFromFirestore(List<Object?> values) {
    return values
        .cast<Map<String, Object?>>()
        .map(GeoPointValue.fromJson)
        .toList();
  }

  static DateTime _requiredDate(Object? value) {
    final parsed = _nullableDate(value);
    if (parsed == null) {
      throw StateError('Expected Firestore date value.');
    }
    return parsed;
  }

  static DateTime? _nullableDate(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    throw StateError('Unsupported Firestore date value: $value');
  }

  static IssueStatus _issueStatus(String value) {
    return IssueStatus.values.firstWhere(
      (status) => status.label == value || status.name == value,
      orElse: () => IssueStatus.open,
    );
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String value,
    T fallback,
  ) {
    for (final item in values) {
      if (item.name == value || _snakeCase(item.name) == value) {
        return item;
      }
    }
    return fallback;
  }

  static String _snakeCase(String value) {
    return value.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    );
  }
}
