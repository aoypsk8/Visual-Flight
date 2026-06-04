// Generated-style config from Firebase Console (com.aoy.visualfocusflight).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCEP_n3CR5GWVPx8zSyb3HD-aXnPKFWQAE',
    appId: '1:248032730149:android:6f785648264f4ac82b73cc',
    messagingSenderId: '248032730149',
    projectId: 'visualfocus-7a7c8',
    storageBucket: 'visualfocus-7a7c8.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCIhaA9icLXR_ZkE83S4eTJlxwnFvXqIW0',
    appId: '1:248032730149:ios:18a7e355d0a3ff302b73cc',
    messagingSenderId: '248032730149',
    projectId: 'visualfocus-7a7c8',
    storageBucket: 'visualfocus-7a7c8.firebasestorage.app',
    iosBundleId: 'com.aoy.visualfocusflight',
  );
}
