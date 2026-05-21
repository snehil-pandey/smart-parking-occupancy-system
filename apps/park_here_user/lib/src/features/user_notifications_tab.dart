import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';

import '../user_app_controller.dart';

class UserNotificationsTab extends StatelessWidget {
  const UserNotificationsTab({
    required this.state,
    required this.controller,
    super.key,
  });

  final UserAppState state;
  final UserAppController controller;

  @override
  Widget build(BuildContext context) {
    final active = state.activeBooking;
    final updates = <_UpdateItem>[
      for (final notification in state.notifications)
        _UpdateItem(
          icon: _iconFor(notification.type),
          title: notification.title,
          body: notification.message,
          isRead: notification.read,
        ),
      if (active != null)
        _UpdateItem(
          icon: Icons.qr_code_2,
          title: 'Active QR ready',
          body:
              'Your booking for ${_locationName(active)} is active. Keep the QR ready at the gate.',
        ),
      if (state.activeQrTicket != null)
        _UpdateItem(
          icon: Icons.verified_outlined,
          title: 'QR status: ${state.activeQrTicket!.status.name}',
          body: 'Expires in ${_remaining(state.activeQrTicket!.expiresAt)}.',
        ),
      if (state.error != null)
        _UpdateItem(
          icon: Icons.error_outline,
          title: 'Firebase update',
          body: state.error!,
          isError: true,
        ),
      _UpdateItem(
        icon: Icons.local_parking_outlined,
        title: 'Realtime availability',
        body:
            '${state.locations.where((area) => area.isBookable).length} parking areas currently available from live Firebase data.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Updates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Booking, QR, issue, and availability alerts.'),
        const SizedBox(height: 18),
        if (updates.isEmpty)
          const Text('No notifications yet.')
        else
          for (final update in updates) _UpdateTile(update: update),
      ],
    );
  }

  IconData _iconFor(AppNotificationType type) => switch (type) {
    AppNotificationType.qrExpiringSoon => Icons.timer_outlined,
    AppNotificationType.qrExpired => Icons.timer_off_outlined,
    AppNotificationType.bookingConfirmed => Icons.check_circle_outline,
    AppNotificationType.bookingCancelled => Icons.cancel_outlined,
    AppNotificationType.issueResponse => Icons.report_gmailerrorred_outlined,
    AppNotificationType.parkingStatus => Icons.local_parking_outlined,
  };

  String _remaining(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'expired';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m';
    }
    return '${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s';
  }

  String _locationName(Booking booking) =>
      state.locations
          .where((location) => location.id == booking.parkingLocationId)
          .firstOrNull
          ?.name ??
      booking.parkingLocationId;
}

class _UpdateItem {
  const _UpdateItem({
    required this.icon,
    required this.title,
    required this.body,
    this.isError = false,
    this.isRead = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isError;
  final bool isRead;
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.update});

  final _UpdateItem update;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        update.icon,
        color: update.isError ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(update.title),
      subtitle: Text(update.body),
      trailing: update.isRead
          ? null
          : const Icon(Icons.circle, size: 10, color: ParkHereTheme.yellow),
    );
  }
}
