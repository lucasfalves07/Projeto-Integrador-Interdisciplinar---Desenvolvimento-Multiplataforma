// lib/firebase_options.dart — versão final revisada e robusta

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// ======================================================================
/// 🔥 Firebase Options — Configurações únicas para cada plataforma
/// Sempre use: Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
/// ======================================================================
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // 🌐 WEB — forçado primeiro pois web ignora defaultTargetPlatform
    if (kIsWeb) {
      return _web;
    }

    // 📱 MOBILE / 💻 DESKTOP
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;

      case TargetPlatform.iOS:
        return _ios;

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        // Desktop usa configuração web como fallback compatível
        return _web;

      default:
        throw UnsupportedError(
          'Plataforma não suportada para configuração do Firebase.',
        );
    }
  }

  // ===================================================================
  // 🌐 WEB
  // ===================================================================
  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
    authDomain: "poliedro-flutter.firebaseapp.com",
    projectId: "poliedro-flutter",
    storageBucket: "poliedro-flutter.appspot.com",
    messagingSenderId: "504037958633",
    appId: "1:504037958633:web:3c1f359cb86381ea246178",
    measurementId: "G-980V6XDF7W",
  );

  // ===================================================================
  // 🤖 ANDROID
  // ===================================================================
  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
    projectId: "poliedro-flutter",
    storageBucket: "poliedro-flutter.appspot.com",
    messagingSenderId: "504037958633",
    appId: "1:504037958633:android:3c1f359cb86381ea246178",
  );

  // ===================================================================
  // 🍎 iOS
  // ===================================================================
  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk80I",
    projectId: "poliedro-flutter",
    storageBucket: "poliedro-flutter.appspot.com",
    messagingSenderId: "504037958633",
    appId: "1:504037958633:ios:3c1f359cb86381ea246178",
    iosBundleId: "com.example.poliedroFlutter",
  );
}