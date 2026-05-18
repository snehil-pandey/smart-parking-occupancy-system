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
          body:
              'Expires at ${state.activeQrTicket!.expiresAt.hour.toString().padLeft(2, '0')}:${state.activeQrTicket!.expiresAt.minute.toString().padLeft(2, '0')}.',
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
            '${state.locations.where((area) => area.isBookable).length} parking areas currently available near SIT Tumkur.',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Updates', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Booking, QR, issue, and availability alerts.'),
        const SizedBox(height: 18),
        for (final update in updates) _UpdateTile(update: update),
      ],
    );
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
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isError;
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
    );
  }
}
