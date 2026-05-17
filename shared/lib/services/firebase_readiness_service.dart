class FirebaseReadiness {
  const FirebaseReadiness({required this.isConfigured, required this.message});

  final bool isConfigured;
  final String message;
}

class FirebaseReadinessService {
  const FirebaseReadinessService();

  FirebaseReadiness check() {
    return const FirebaseReadiness(
      isConfigured: false,
      message:
          'Firebase is not configured yet. The app is running with local demo repositories.',
    );
  }
}
