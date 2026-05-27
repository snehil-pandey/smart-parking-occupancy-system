import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_models.dart';
import 'qr_verification_service.dart';
import 'result_screen.dart';
import 'scanner_location_service.dart';

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
  final ScannerLocationService _locationService = ScannerLocationService();

  late Future<_ScannerLocationState> _locationFuture;
  ScannerLocationContext? _scannerContext;
  bool _busy = false;
  String _status = 'Scan a Park Here QR ticket.';

  @override
  void initState() {
    super.initState();
    _locationFuture = _loadLocationState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_ScannerLocationState> _loadLocationState() async {
    final options = await _locationService.loadOptions();
    final saved = await _locationService.loadSavedContext();
    final context = _resolveSavedContext(saved, options);
    _scannerContext = context;
    return _ScannerLocationState(options: options, context: context);
  }

  ScannerLocationContext? _resolveSavedContext(
    ScannerLocationContext? saved,
    ScannerLocationOptions options,
  ) {
    if (saved == null) {
      return null;
    }
    final area = options.parkingAreas
        .where((candidate) => candidate.areaId == saved.areaId)
        .firstOrNull;
    if (area == null) {
      return null;
    }
    final gate = area.gatePoints
        .where((candidate) => candidate.gateId == saved.gateId)
        .firstOrNull;
    if (gate == null) {
      return null;
    }
    final regionName = options.regions
        .where((region) => region.regionId == area.regionId)
        .map((region) => region.name)
        .firstOrNull;
    return ScannerLocationContext(
      regionId: area.regionId,
      regionName: regionName ?? saved.regionName,
      areaId: area.areaId,
      areaName: area.name,
      gateId: gate.gateId,
      gateName: gate.name,
    );
  }

  Future<void> _reloadLocations() async {
    setState(() {
      _locationFuture = _loadLocationState();
    });
  }

  Future<void> _setScannerContext(ScannerLocationContext context) async {
    await _locationService.saveContext(context);
    if (!mounted) {
      return;
    }
    setState(() {
      _scannerContext = context;
      _locationFuture = Future.value(
        _ScannerLocationState(
          options: _ScannerLocationState.lastOptions!,
          context: context,
        ),
      );
      _status = 'Scan at ${context.gateName}.';
    });
  }

  Future<void> _changeScannerLocation(ScannerLocationOptions options) async {
    await _controller.stop();
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<ScannerLocationContext>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ScannerLocationSheet(options: options, current: _scannerContext),
    );
    if (selected != null) {
      await _setScannerContext(selected);
    }
    if (mounted && _scannerContext != null) {
      await _controller.start();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final scannerContext = _scannerContext;
    if (_busy || scannerContext == null) {
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
      _status = 'Verifying ticket at ${scannerContext.gateName}...';
    });
    await _controller.stop();
    final result = await _service.verify(raw, scannerContext: scannerContext);
    debugPrint(
      'Park Here Scanner: verification result for ${result.qrId}: ${result.status.name}',
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResultScreen(initialResult: result, scannerContext: scannerContext),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _status = 'Scan at ${scannerContext.gateName}.';
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    const noEsp = bool.fromEnvironment('NO_ESP');
    return FutureBuilder<_ScannerLocationState>(
      future: _locationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: _ScannerLoading(message: 'Loading gates...')),
          );
        }
        if (snapshot.hasError) {
          return _LocationErrorScreen(onRetry: _reloadLocations);
        }
        final locationState = snapshot.data!;
        _ScannerLocationState.lastOptions = locationState.options;
        if (locationState.options.isEmpty) {
          return _NoLocationsScreen(onRetry: _reloadLocations);
        }
        if (_scannerContext == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Choose Scanner Location')),
            body: _ScannerLocationSetup(
              options: locationState.options,
              onSelected: _setScannerContext,
              onRetry: _reloadLocations,
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Park Here Scanner'),
            actions: [
              IconButton(
                tooltip: 'Change scanner location',
                onPressed: () => _changeScannerLocation(locationState.options),
                icon: const Icon(Icons.tune),
              ),
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
              _CurrentScannerLocation(context: _scannerContext!),
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
      },
    );
  }
}

class _ScannerLocationState {
  const _ScannerLocationState({required this.options, required this.context});

  static ScannerLocationOptions? lastOptions;

  final ScannerLocationOptions options;
  final ScannerLocationContext? context;
}

class _ScannerLocationSetup extends StatefulWidget {
  const _ScannerLocationSetup({
    required this.options,
    required this.onSelected,
    required this.onRetry,
  });

  final ScannerLocationOptions options;
  final Future<void> Function(ScannerLocationContext context) onSelected;
  final Future<void> Function() onRetry;

  @override
  State<_ScannerLocationSetup> createState() => _ScannerLocationSetupState();
}

class _ScannerLocationSetupState extends State<_ScannerLocationSetup> {
  String? _regionId;
  String? _areaId;
  String? _gateId;

  @override
  void initState() {
    super.initState();
    _regionId = widget.options.regions.firstOrNull?.regionId;
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.options.parkingAreas
        .where((area) => _regionId == null || area.regionId == _regionId)
        .toList();
    final selectedArea = areas
        .where((area) => area.areaId == _areaId)
        .firstOrNull;
    final gates = selectedArea?.gatePoints ?? const <GatePointSummary>[];
    final selectedGate = gates
        .where((gate) => gate.gateId == _gateId)
        .firstOrNull;
    final canSave = selectedArea != null && selectedGate != null;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Current Scanner Location',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the parking area and gate this Android scanner is emulating.',
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: _regionId,
          decoration: const InputDecoration(labelText: 'Region'),
          items: widget.options.regions
              .map(
                (region) => DropdownMenuItem(
                  value: region.regionId,
                  child: Text(region.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _regionId = value;
            _areaId = null;
            _gateId = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _areaId,
          decoration: const InputDecoration(labelText: 'Parking area'),
          items: areas
              .map(
                (area) => DropdownMenuItem(
                  value: area.areaId,
                  child: Text(area.name),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _areaId = value;
            _gateId = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _gateId,
          decoration: const InputDecoration(labelText: 'Gate'),
          items: gates
              .map(
                (gate) => DropdownMenuItem(
                  value: gate.gateId,
                  child: Text('${gate.name} (${gate.type})'),
                ),
              )
              .toList(),
          onChanged: gates.isEmpty
              ? null
              : (value) => setState(() => _gateId = value),
        ),
        if (selectedArea != null && gates.isEmpty) ...[
          const SizedBox(height: 10),
          const _InlineWarning(
            message:
                'This parking area has no gates. Add a gate in Admin first.',
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: canSave
              ? () async {
                  final region = widget.options.regions
                      .where(
                        (candidate) =>
                            candidate.regionId == selectedArea.regionId,
                      )
                      .firstOrNull;
                  await widget.onSelected(
                    ScannerLocationContext(
                      regionId: selectedArea.regionId,
                      regionName: region?.name ?? selectedArea.regionId,
                      areaId: selectedArea.areaId,
                      areaName: selectedArea.name,
                      gateId: selectedGate.gateId,
                      gateName: selectedGate.name,
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.check),
          label: const Text('Use This Location'),
        ),
        TextButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reload Firebase locations'),
        ),
      ],
    );
  }
}

class _ScannerLocationSheet extends StatelessWidget {
  const _ScannerLocationSheet({required this.options, this.current});

  final ScannerLocationOptions options;
  final ScannerLocationContext? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: _ScannerLocationSetup(
          options: options,
          onRetry: () async {},
          onSelected: (contextValue) async {
            Navigator.of(context).pop(contextValue);
          },
        ),
      ),
    );
  }
}

class _CurrentScannerLocation extends StatelessWidget {
  const _CurrentScannerLocation({required this.context});

  final ScannerLocationContext context;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.sensor_door_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${this.context.areaName} / ${this.context.gateName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoLocationsScreen extends StatelessWidget {
  const _NoLocationsScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Park Here Scanner')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 64),
              const SizedBox(height: 12),
              Text(
                'No parking gates found',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create parking areas and gates in the Admin app, then reload.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationErrorScreen extends StatelessWidget {
  const _LocationErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Park Here Scanner')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 12),
              const Text(
                'Unable to load scanner locations.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
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
