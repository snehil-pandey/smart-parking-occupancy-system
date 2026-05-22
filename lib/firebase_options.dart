// File generated from the Park Here Firebase project configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Park Here Scanner is configured for Android fallback mode.',
        );
      default:
        throw UnsupportedError('Unsupported Firebase platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCpN3gvb0sZ2u4NWS3fgVfslqxSzE8fDGE',
    appId: '1:481474250871:web:b34ff063698d4cd0abde72',
    messagingSenderId: '481474250871',
    projectId: 'park-here-dev',
    authDomain: 'park-here-dev.firebaseapp.com',
    storageBucket: 'park-here-dev.firebasestorage.app',
    measurementId: 'G-1Z3GW598TM',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCeJlzTk7Pm0Z_A_sooCQoWCXW0En6xfOM',
    appId: '1:481474250871:android:121167f3cb8dfc91abde72',
    messagingSenderId: '481474250871',
    projectId: 'park-here-dev',
    storageBucket: 'park-here-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCZhsSlXdTZ357gws7p1fSlNfPdR_Mkfbo',
    appId: '1:481474250871:ios:98419088e60a637aabde72',
    messagingSenderId: '481474250871',
    projectId: 'park-here-dev',
    storageBucket: 'park-here-dev.firebasestorage.app',
    iosBundleId: 'com.parkhere.parkHereUser',
  );
}
