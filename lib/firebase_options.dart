import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBgK8ZKmZ0N329vOTfpiAyYAhPu_mhyTAM',
    appId: '1:179443689337:web:31ca73ac50811b286931a8',
    messagingSenderId: '179443689337',
    projectId: 'app-10-1b5fd',
    authDomain: 'app-10-1b5fd.firebaseapp.com',
    storageBucket: 'app-10-1b5fd.firebasestorage.app',
    measurementId: 'G-3FNWYX8NLE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgK8ZKmZ0N329vOTfpiAyYAhPu_mhyTAM',
    appId: '1:179443689337:android:261e6f41067b96d56931a8',
    messagingSenderId: '179443689337',
    projectId: 'app-10-1b5fd',
    storageBucket: 'app-10-1b5fd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBgK8ZKmZ0N329vOTfpiAyYAhPu_mhyTAM',
    appId: '1:179443689337:ios:fc82e09530bb3e6d6931a8',
    messagingSenderId: '179443689337',
    projectId: 'app-10-1b5fd',
    storageBucket: 'app-10-1b5fd.firebasestorage.app',
    iosBundleId: 'com.supportclub.carteNabil',
  );
}
