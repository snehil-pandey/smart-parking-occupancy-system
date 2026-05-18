enum AppNotificationType {
  qrExpiringSoon,
  qrExpired,
  bookingConfirmed,
  bookingCancelled,
  issueResponse,
  parkingStatus,
}

class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.relatedBookingId,
    this.relatedAreaId,
    required this.read,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String message;
  final String? relatedBookingId;
  final String? relatedAreaId;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    notificationId: notificationId,
    userId: userId,
    type: type,
    title: title,
    message: message,
    relatedBookingId: relatedBookingId,
    relatedAreaId: relatedAreaId,
    read: read ?? this.read,
    createdAt: createdAt,
  );
}
