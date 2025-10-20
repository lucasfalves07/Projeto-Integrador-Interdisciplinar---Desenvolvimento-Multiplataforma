// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart'; // Gerado pelo FlutterFire CLI
import 'router.dart'; // GoRouter configurado
import 'styles/theme.dart'; // AppTheme.light / AppTheme.dark
import 'theme/theme_controller.dart'; // Controlador de tema global

// 🔔 Handler de mensagens recebidas em segundo plano
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📩 [BG] Mensagem recebida: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 Captura erros do Flutter framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Erro Flutter: ${details.exceptionAsString()}');
  };

  // ⚙️ Executa com proteção contra exceções fora da árvore Flutter
  await runZonedGuarded<Future<void>>(() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e, st) {
      debugPrint('❌ Erro ao inicializar Firebase: $e\n$st');
    }

    // 🌗 Controlador global de tema
    final themeController = ThemeController();
    await themeController.loadTheme();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => themeController),
          StreamProvider<User?>.value(
            value: FirebaseAuth.instance.authStateChanges(),
            initialData: null,
          ),
        ],
        child: const PoliedroApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('❌ Uncaught zone error: $error\n$stack');
  });
}

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
    _initPushNotifications();
  }

  Future<void> _initPushNotifications() async {
    try {
      // 🚀 Solicita permissão (iOS e Web)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 Permissão FCM: ${settings.authorizationStatus}');

      // 🔑 Obtém o token FCM do dispositivo
      final token = await _messaging.getToken();
      debugPrint('📱 Token FCM: $token');

      // 🔥 Salva token no Firestore vinculado ao usuário
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 🔄 Atualiza token automaticamente se mudar
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
            'fcmToken': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        debugPrint('🔄 Token atualizado: $newToken');
      });

      // 🎯 Mensagens em foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          debugPrint('📩 [FG] ${notification.title} - ${notification.body}');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${notification.title}\n${notification.body}'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      });

      // 🚪 App aberto via notificação
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📬 Notificação clicada: ${message.data}');
        // 👉 você pode redirecionar o usuário com:
        // context.go('/aluno/materiais'); por exemplo
      });
    } catch (e) {
      debugPrint('❌ Erro ao inicializar notificações: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp.router(
      title: 'Poliedro Flutter',
      debugShowCheckedModeBanner: false,

      // 🎨 Tema dinâmico (Material 3)
      theme: AppTheme.light.copyWith(useMaterial3: true),
      darkTheme: AppTheme.dark.copyWith(useMaterial3: true),
      themeMode: themeController.themeMode,

      // 🌐 Rotas via GoRouter
      routerConfig: appRouter,

      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
