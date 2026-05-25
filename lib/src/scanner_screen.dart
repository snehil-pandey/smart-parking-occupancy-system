import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_verification_service.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({this.projectId, super.key});

  final String? projectId;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final QrVerificationService _service = QrVerificationService();

  bool _busy = false;
  String _status = 'Scan a Park Here QR ticket.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) {
      return;
    }
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    debugPrint('Park Here Scanner: raw QR scanned: $raw');
    setState(() {
      _busy = true;
      _status = 'Verifying ticket...';
    });
    await _controller.stop();
    final result = await _service.verify(raw);
    debugPrint(
      'Park Here Scanner: verification result for ${result.qrId}: ${result.status.name}',
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(initialResult: result),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _status = 'Scan a Park Here QR ticket.';
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    const noEsp = bool.fromEnvironment('NO_ESP');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Park Here Scanner'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(noEsp ? 'NO_ESP' : 'Scanner'),
              avatar: const Icon(Icons.qr_code_scanner, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                const _ScanOverlay(),
                if (_busy)
                  const Center(
                    child: _ScannerLoading(message: 'Checking Firebase...'),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_busy ? Icons.hourglass_top : Icons.qr_code_scanner),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.projectId == null
                          ? _status
                          : '$_status (${widget.projectId})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 4,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _ScannerLoading extends StatelessWidget {
  const _ScannerLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}
