import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../user_app_controller.dart';
import '../widgets/user_status_strip.dart';

class UserBookingsTab extends StatelessWidget {
  const UserBookingsTab({
    required this.state,
    required this.controller,
    super.key,
  });

  final UserAppState state;
  final UserAppController controller;

  @override
  Widget build(BuildContext context) {
    final active = state.activeBooking;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Bookings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Manage active QR tickets and parking history.'),
        if (state.actionMessage != null) ...[
          const SizedBox(height: 12),
          StatusStrip(message: state.actionMessage!),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 12),
          StatusStrip(message: state.error!, isError: true),
        ],
        const SizedBox(height: 18),
        if (active == null)
          const _EmptyBookingState()
        else
          _ActiveBookingCard(
            booking: active,
            activeQrTicket: state.activeQrTicket,
            location: _locationFor(active),
            onCancel: controller.cancelActiveBooking,
          ),
        const SizedBox(height: 22),
        Text('History', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (state.bookingHistory.isEmpty)
          const Text('No bookings yet.')
        else
          for (final booking in state.bookingHistory)
            _BookingHistoryTile(
              booking: booking,
              location: _locationFor(booking),
            ),
      ],
    );
  }

  ParkingLocation? _locationFor(Booking booking) => state.locations
      .where((location) => location.id == booking.parkingLocationId)
      .firstOrNull;
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({
    required this.booking,
    required this.activeQrTicket,
    required this.location,
    required this.onCancel,
  });

  final Booking booking;
  final ActiveQrTicket? activeQrTicket;
  final ParkingLocation? location;
  final Future<void> Function({String? reason}) onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF9E2),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active booking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                QrImageView(
                  data: booking.qrPayload,
                  size: 118,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location?.name ?? booking.parkingLocationId,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(booking.vehicleNumber),
                      Text(
                        '${formatInr(booking.price)} - ${booking.durationHours} hours',
                      ),
                      Text(
                        activeQrTicket == null
                            ? 'QR waiting for active ticket sync'
                            : 'QR ${activeQrTicket!.status.name} until ${_time(activeQrTicket!.expiresAt)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel booking'),
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _confirmCancel(BuildContext context) {
    final fine = (location?.pricePerHour ?? 0) > 10 ? 10.0 : 0.0;
    final reason = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fine > 0
                  ? 'A ${formatInr(fine)} cancellation fine will be recorded.'
                  : 'No cancellation fine applies for this parking area.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Reason optional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () {
              onCancel(reason: reason.text);
              Navigator.pop(context);
            },
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
  }
}

class _BookingHistoryTile extends StatelessWidget {
  const _BookingHistoryTile({required this.booking, required this.location});

  final Booking booking;
  final ParkingLocation? location;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        booking.status == BookingStatus.cancelled
            ? Icons.cancel_outlined
            : Icons.confirmation_number_outlined,
      ),
      title: Text(location?.name ?? booking.parkingLocationId),
      subtitle: Text(
        '${booking.status.name} - ${formatInr(booking.price)}'
        '${booking.cancellationFine > 0 ? ' - fine ${formatInr(booking.cancellationFine)}' : ''}',
      ),
      trailing: Text(
        '${booking.createdAt.day}/${booking.createdAt.month}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyBookingState extends StatelessWidget {
  const _EmptyBookingState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.confirmation_number_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text('No active booking. Book a parking area from Home.'),
            ),
          ],
        ),
      ),
    );
  }
}
