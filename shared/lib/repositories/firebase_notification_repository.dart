import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../services/firebase_collection_paths.dart';
import 'notification_repository.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppNotification>> watchForUser(String userId, {int limit = 30}) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _notificationFromDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> upsert(AppNotification notification) async {
    await _notifications.doc(notification.notificationId).set({
      'notificationId': notification.notificationId,
      'userId': notification.userId,
      'type': notification.type.name,
      'title': notification.title,
      'message': notification.message,
      'relatedBookingId': notification.relatedBookingId,
      'relatedAreaId': notification.relatedAreaId,
      'read': notification.read,
      'createdAt': Timestamp.fromDate(notification.createdAt),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'read': true});
  }

  AppNotification _notificationFromDoc(String id, Map<String, Object?> json) {
    final typeName = json['type'] as String? ?? '';
    final type = AppNotificationType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    return AppNotification(
      notificationId: json['notificationId'] as String? ?? id,
      userId: json['userId'] as String? ?? '',
      type: type ?? AppNotificationType.parkingStatus,
      title: json['title'] as String? ?? 'Park Here update',
      message: json['message'] as String? ?? '',
      relatedBookingId: json['relatedBookingId'] as String?,
      relatedAreaId: json['relatedAreaId'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: _date(json['createdAt']),
    );
  }

  DateTime _date(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirebaseCollectionPaths.notifications);
}
