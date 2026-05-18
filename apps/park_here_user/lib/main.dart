import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'firebase_options.dart';
import 'src/user_app_controller.dart';
import 'src/user_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? setupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } on Object catch (error) {
    setupError = error;
  }
  runApp(
    ProviderScope(
      overrides: [
        firebaseReadinessProvider.overrideWithValue(
          FirebaseReadinessService(
            isConfigured: setupError == null,
            error: setupError,
          ).check(),
        ),
      ],
      child: const ParkHereUserApp(),
    ),
  );
}

class ParkHereUserApp extends StatelessWidget {
  const ParkHereUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Park Here',
      theme: ParkHereTheme.userTheme(),
      home: const UserHomeScreen(),
    );
  }
}
