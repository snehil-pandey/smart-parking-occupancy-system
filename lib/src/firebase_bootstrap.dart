import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.ready, this.error});

  final bool ready;
  final Object? error;
}

class FirebaseBootstrap {
  const FirebaseBootstrap();

  Future<FirebaseBootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp();
      return const FirebaseBootstrapResult(ready: true);
    } on Object catch (error) {
      return FirebaseBootstrapResult(ready: false, error: error);
    }
  }
}
