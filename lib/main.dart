import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'styles/theme.dart';
import 'theme/theme_controller.dart';

/// ===========================================================================
/// 🔹 Handler de notificações em background (mobile)
/// ===========================================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[BG] Mensagem recebida: ${message.notification?.title}');
  } catch (_) {}
}

/// ===========================================================================
/// 🔹 MAIN
/// ===========================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mantém fontes funcionando mesmo sem assets locais.
  GoogleFonts.config.allowRuntimeFetching = true;

  // Captura global de erros Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("FlutterError: ${details.exceptionAsString()}");
  };

  try {
    // Firebase init (seguro mesmo se carregado 2x no web)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Background messaging
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    }
  } catch (e, st) {
    debugPrint('❌ Erro ao iniciar Firebase: $e\n$st');
  }

  // Tema
  final themeController = ThemeController();
  await themeController.loadTheme();

  // Necessário para deep-links corretos no Web
  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeController),

        /// Usuário logado globalmente
        StreamProvider<User?>.value(
          initialData: null,
          value: FirebaseAuth.instance.authStateChanges(),
        ),
      ],
      child: const PoliedroApp(),
    ),
  );
}

/// ===========================================================================
/// 🔹 APP PRINCIPAL
/// ===========================================================================
class PoliedroApp extends StatefulWidget {
  const PoliedroApp({super.key});

  @override
  State<PoliedroApp> createState() => _PoliedroAppState();
}

class _PoliedroAppState extends State<PoliedroApp> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initPush();
    }
  }

  /// =======================================================================
  /// 🔹 PUSH NOTIFICATIONS
  /// =======================================================================
  Future<void> _initPush() async {
    try {
      NotificationSettings settings;

      if (kIsWeb) {
        settings = await _messaging.getNotificationSettings();
      } else {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      debugPrint("🔔 Permissão FCM: ${settings.authorizationStatus}");

      // Token
      final token = await _messaging.getToken();
      debugPrint("📨 TOKEN FCM: $token");

      await _saveFCMToken(token);

      // Atualização automática do token
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint("📨 Novo TOKEN FCM: $newToken");
        await _saveFCMToken(newToken);
      });

      // Foreground notifications
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (!mounted || n == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${n.title ?? "Notificação"}\n${n.body ?? ""}',
              style: const TextStyle(fontSize: 14),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e, st) {
      debugPrint("❌ Erro FCM: $e\n$st");
    }
  }

  /// =======================================================================
  /// 🔹 Salvar token FCM no Firestore (somente se logado)
  /// =======================================================================
  Future<void> _saveFCMToken(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "fcmToken": token,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erro ao salvar token FCM: $e");
    }
  }

  /// =======================================================================
  /// 🔹 BUILD
  /// =======================================================================
  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp.router(
      title: "Poliedro Flutter",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(useMaterial3: true),
      darkTheme: AppTheme.dark.copyWith(useMaterial3: true),
      themeMode: themeController.themeMode,
      routerConfig: appRouter,

      builder: (context, child) {
        // Remover scrollbars no Web
        return ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
