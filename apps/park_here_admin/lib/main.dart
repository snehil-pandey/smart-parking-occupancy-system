import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'firebase_options.dart';
import 'src/admin_app_controller.dart';
import 'src/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? setupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error) {
    setupError = error;
  }
  runApp(
    ProviderScope(
      overrides: [
        adminFirebaseReadinessProvider.overrideWithValue(
          FirebaseReadinessService(
            isConfigured: setupError == null,
            error: setupError,
          ).check(),
        ),
      ],
      child: const ParkHereAdminApp(),
    ),
  );
}

class ParkHereAdminApp extends StatelessWidget {
  const ParkHereAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Park Here: Location Administrator',
      theme: ParkHereTheme.adminTheme(),
      home: const AdminDashboardScreen(),
    );
  }
}
