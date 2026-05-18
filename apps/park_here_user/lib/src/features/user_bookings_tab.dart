import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openQrViewer(context),
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
                    data: _qrData,
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
      ),
    );
  }

  String get _qrData =>
      activeQrTicket?.qrId ??
      const QrPayloadService().parse(booking.qrPayload).qrId;

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _openQrViewer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _QrTicketViewer(
        qrData: _qrData,
        booking: booking,
        activeQrTicket: activeQrTicket,
        location: location,
      ),
    );
  }

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

class _QrTicketViewer extends StatefulWidget {
  const _QrTicketViewer({
    required this.qrData,
    required this.booking,
    required this.activeQrTicket,
    required this.location,
  });

  final String qrData;
  final Booking booking;
  final ActiveQrTicket? activeQrTicket;
  final ParkingLocation? location;

  @override
  State<_QrTicketViewer> createState() => _QrTicketViewerState();
}

class _QrTicketViewerState extends State<_QrTicketViewer> {
  double? _previousBrightness;

  @override
  void initState() {
    super.initState();
    _raiseBrightness();
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt =
        widget.activeQrTicket?.expiresAt ?? widget.booking.endTime;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close QR',
              ),
            ),
            Text(
              widget.location?.name ?? widget.booking.parkingLocationId,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _ExpiryCountdown(expiresAt: expiresAt),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: QrImageView(
                  data: widget.qrData,
                  size: 292,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Status: ${widget.activeQrTicket?.status.name ?? widget.booking.status.name}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Valid until ${_dateTime(expiresAt)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _raiseBrightness() async {
    try {
      final screen = ScreenBrightness();
      _previousBrightness = await screen.application;
      await screen.setApplicationScreenBrightness(1);
    } on Object {
      // Web and some desktop targets do not expose brightness control.
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      final previous = _previousBrightness;
      if (previous == null) {
        return;
      }
      await ScreenBrightness().setApplicationScreenBrightness(previous);
    } on Object {
      // Best-effort only; the QR remains usable even without brightness APIs.
    }
  }

  String _dateTime(DateTime value) =>
      '${value.day}/${value.month} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ExpiryCountdown extends StatelessWidget {
  const _ExpiryCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => 0),
      builder: (context, _) {
        final remaining = expiresAt.difference(DateTime.now());
        final text = remaining.isNegative
            ? 'Expired'
            : '${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${remaining.inSeconds.remainder(60).toString().padLeft(2, '0')} remaining';
        return Text(text, style: const TextStyle(color: Colors.white));
      },
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
