import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.ready,
    this.projectId,
    this.error,
  });

  final bool ready;
  final String? projectId;
  final Object? error;
}

class FirebaseBootstrap {
  const FirebaseBootstrap();

  Future<FirebaseBootstrapResult> initialize() async {
    try {
      final app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final projectId = app.options.projectId;
      debugPrint('Park Here Scanner: Firebase initialized.');
      debugPrint('Park Here Scanner: Firebase project id: $projectId');
      FirebaseFirestore.instance;
      debugPrint('Park Here Scanner: Firestore instance ready.');
      debugPrint(
        'Park Here Scanner: Firebase Auth is not used in fallback mode.',
      );
      return FirebaseBootstrapResult(ready: true, projectId: projectId);
    } on Object catch (error) {
      debugPrint('Park Here Scanner: Firebase initialization failed: $error');
      return FirebaseBootstrapResult(
        ready: false,
        projectId: null,
        error: error,
      );
    }
  }
}
