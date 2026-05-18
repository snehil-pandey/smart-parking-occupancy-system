import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:park_here_shared/park_here_shared.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class QrExpiryNotificationService {
  QrExpiryNotificationService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  String? _scheduledQrId;

  Future<void> scheduleForTicket({
    required ActiveQrTicket? ticket,
    required String parkingName,
  }) async {
    if (ticket == null || ticket.status != ActiveQrStatus.active) {
      await cancelScheduled();
      return;
    }
    if (_scheduledQrId == ticket.qrId) {
      return;
    }
    await cancelScheduled();
    _scheduledQrId = ticket.qrId;
    final now = DateTime.now();
    await _scheduleThreshold(
      id: _notificationId(ticket.qrId, 10),
      when: ticket.expiresAt.subtract(const Duration(minutes: 10)),
      now: now,
      title: 'QR expires in 10 minutes',
      body: 'Your Park Here ticket for $parkingName is expiring soon.',
    );
    await _scheduleThreshold(
      id: _notificationId(ticket.qrId, 2),
      when: ticket.expiresAt.subtract(const Duration(minutes: 2)),
      now: now,
      title: 'QR expires in 2 minutes',
      body: 'Keep the QR ready for gate verification.',
    );
    await _scheduleThreshold(
      id: _notificationId(ticket.qrId, 0),
      when: ticket.expiresAt,
      now: now,
      title: 'QR expired',
      body: 'Your Park Here QR ticket has expired.',
    );
  }

  Future<void> cancelScheduled() async {
    if (_scheduledQrId == null || kIsWeb) {
      _scheduledQrId = null;
      return;
    }
    final qrId = _scheduledQrId!;
    for (final minutes in [10, 2, 0]) {
      await _notifications.cancel(_notificationId(qrId, minutes));
    }
    _scheduledQrId = null;
  }

  Future<void> _scheduleThreshold({
    required int id,
    required DateTime when,
    required DateTime now,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !when.isAfter(now)) {
      return;
    }
    try {
      await _ensureInitialized();
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'qr_expiry',
            'QR expiry alerts',
            channelDescription: 'Alerts before active QR tickets expire.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on Object {
      // Local notifications are best-effort because web/desktop/browser
      // permission models vary. In-app notifications remain the reliable path.
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  int _notificationId(String qrId, int threshold) =>
      Object.hash(qrId, threshold) & 0x7fffffff;
}
