import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyBUN9UbDnsD0K5E5DxGpGaoQs2xpLnNayE',
      appId: '1:911900427556:web:230e73ea3b3d1c0db51fb1',
      messagingSenderId: '911900427556',
      projectId: 'elite-by-s',
      authDomain: 'elite-by-s.firebaseapp.com',
      storageBucket: 'elite-by-s.firebasestorage.app',
    );
  }
}
