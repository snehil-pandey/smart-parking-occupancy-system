part of '../../admin_dashboard_screen.dart';

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (state.bookings.isEmpty)
              const _EmptyState(
                message:
                    'Bookings will appear here once drivers reserve slots.',
              )
            else
              for (final booking in state.bookings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(booking.vehicleNumber),
                  subtitle: Text(
                    '${booking.id} • ${booking.status.name} • ${formatInr(booking.price)}',
                  ),
                  trailing: booking.status == BookingStatus.active
                      ? IconButton(
                          tooltip: 'Mark completed',
                          onPressed: () => controller.markCompleted(booking),
                          icon: const Icon(Icons.check_circle_outline),
                        )
                      : const Icon(Icons.done_all),
                  onTap: () => _showBookingDetails(context, booking),
                ),
            const Divider(height: 28),
            Text(
              'Weekly/monthly income',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(value: 0.62),
            const SizedBox(height: 8),
            const Text('Placeholder for chart-backed income analytics.'),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Booking booking) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(booking.id),
        content: SelectableText(booking.qrPayload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
