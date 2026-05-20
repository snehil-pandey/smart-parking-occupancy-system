import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';
import 'scanner_screen.dart';

class ParkHereScannerApp extends StatelessWidget {
  const ParkHereScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Park Here Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF7C948),
          brightness: Brightness.light,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const BootstrapScreen(),
    );
  }
}

class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late Future<FirebaseBootstrapResult> _future;

  @override
  void initState() {
    super.initState();
    _future = const FirebaseBootstrap().initialize();
  }

  void _retry() {
    setState(() {
      _future = const FirebaseBootstrap().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseBootstrapResult>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _LoadingScaffold(message: 'Connecting to Firebase...');
        }

        final result = snapshot.data!;
        if (!result.ready) {
          return _SetupErrorScreen(onRetry: _retry);
        }

        return const ScannerScreen();
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_parking, size: 76),
              const SizedBox(height: 16),
              Text(
                'Park Here Scanner',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              const SizedBox(
                width: 180,
                child: LinearProgressIndicator(minHeight: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupErrorScreen extends StatelessWidget {
  const _SetupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Firebase setup needed',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Add Android Firebase configuration before using the scanner.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
