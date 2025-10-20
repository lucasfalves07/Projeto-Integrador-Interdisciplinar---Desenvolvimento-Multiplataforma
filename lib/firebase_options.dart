// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // 🔹 Configuração para Web
      return const FirebaseOptions(
        apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
        authDomain: "poliedro-flutter.firebaseapp.com",
        projectId: "poliedro-flutter",
        storageBucket: "poliedro-flutter.firebasestorage.app",
        messagingSenderId: "504037958633",
        appId: "1:504037958633:web:3c1f359cb86381ea246178",
        measurementId: "G-980V6XDF7W",
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
          projectId: "poliedro-flutter",
          storageBucket: "poliedro-flutter.firebasestorage.app",
          messagingSenderId: "504037958633",
          appId: "1:504037958633:web:3c1f359cb86381ea246178",
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
          projectId: "poliedro-flutter",
          storageBucket: "poliedro-flutter.firebasestorage.app",
          messagingSenderId: "504037958633",
          appId: "1:504037958633:web:3c1f359cb86381ea246178",
          iosBundleId: "com.example.poliedroFlutter", // ajuste se mudar
        );
      default:
        throw UnsupportedError(
          "Plataforma não suportada para FirebaseOptions",
        );
    }
  }
}
