import 'package:flutter/material.dart';

import 'qr_models.dart';
import 'qr_verification_service.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.initialResult, super.key});

  final QrScanResult initialResult;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final QrVerificationService _service = QrVerificationService();
  late QrScanResult _result;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
  }

  Future<void> _confirmEntry() async {
    if (!_result.canConfirm || _confirming) {
      return;
    }
    setState(() => _confirming = true);
    final next = await _service.consume(_result);
    if (!mounted) {
      return;
    }
    setState(() {
      _result = next;
      _confirming = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = _result.booking;
    final ticket = _result.ticket;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _iconFor(_result.status),
                            color: _colorFor(_result.status),
                            size: 34,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _result.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_result.message),
                      if (booking != null && ticket != null) ...[
                        const Divider(height: 28),
                        _InfoRow(
                          label: 'Parking',
                          value:
                              _result.parkingArea?.name ??
                              booking.parkingAreaId,
                        ),
                        _InfoRow(
                          label: 'Vehicle',
                          value: booking.vehicleNumber,
                        ),
                        _InfoRow(
                          label: 'Valid until',
                          value: _format(ticket.expiresAt),
                        ),
                        _InfoRow(label: 'Ticket', value: ticket.status.name),
                        _InfoRow(label: 'Booking', value: booking.status.name),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _result.canConfirm && !_confirming
                    ? _confirmEntry
                    : null,
                icon: _confirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified),
                label: const Text('Confirm Entry'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _confirming
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(QrScanStatus status) {
    return switch (status) {
      QrScanStatus.valid => Icons.check_circle,
      QrScanStatus.consumed => Icons.verified,
      QrScanStatus.expired => Icons.timer_off,
      QrScanStatus.alreadyUsed => Icons.block,
      QrScanStatus.parkingActive => Icons.local_parking,
      QrScanStatus.invalidQr => Icons.error_outline,
      QrScanStatus.notFound => Icons.search_off,
      QrScanStatus.bookingNotFound => Icons.link_off,
      QrScanStatus.bookingNotActive => Icons.info_outline,
      QrScanStatus.networkError => Icons.wifi_off,
    };
  }

  Color _colorFor(QrScanStatus status) {
    return switch (status) {
      QrScanStatus.valid ||
      QrScanStatus.consumed ||
      QrScanStatus.parkingActive => Colors.green,
      QrScanStatus.expired ||
      QrScanStatus.alreadyUsed ||
      QrScanStatus.invalidQr => Colors.red,
      QrScanStatus.notFound ||
      QrScanStatus.bookingNotFound ||
      QrScanStatus.bookingNotActive => Colors.orange,
      QrScanStatus.networkError => Colors.blueGrey,
    };
  }

  String _format(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
