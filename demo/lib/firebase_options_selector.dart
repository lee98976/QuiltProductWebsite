import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

// This standalone website demo has no production configuration or selectable profile.
class QuiltFirebaseOptions {
  QuiltFirebaseOptions._();
  static const bool isDemo = true;
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'demo-api-key-not-production',
    appId: '1:000000000000:web:demo',
    messagingSenderId: '000000000000',
    projectId: 'quilt-demo-public',
    authDomain: 'quilt-demo-public.firebaseapp.com',
    storageBucket: 'quilt-demo-public.firebasestorage.app',
  );
}
