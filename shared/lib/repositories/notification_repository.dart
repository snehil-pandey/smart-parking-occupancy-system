import '../models/app_notification.dart';

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String userId, {int limit = 30});

  Future<void> upsert(AppNotification notification);

  Future<void> markRead(String notificationId);
}
