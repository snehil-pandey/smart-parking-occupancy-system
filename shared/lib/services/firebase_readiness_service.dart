class FirebaseReadiness {
  const FirebaseReadiness({required this.isConfigured, required this.message});

  final bool isConfigured;
  final String message;
}

class FirebaseReadinessService {
  const FirebaseReadinessService({this.isConfigured = true, this.error});

  final bool isConfigured;
  final Object? error;

  FirebaseReadiness check() {
    if (!isConfigured) {
      return FirebaseReadiness(
        isConfigured: false,
        message:
            'Firebase setup failed: ${error ?? 'missing configuration'}. Run FlutterFire setup and restart.',
      );
    }
    return const FirebaseReadiness(
      isConfigured: true,
      message: 'Firebase is connected. Runtime data is loaded from Firestore.',
    );
  }
}
