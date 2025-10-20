import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/cards/index.dart';

/// Tela de Login:
/// - Exibe o [LoginCard] com campos de email e senha.
/// - Se já estiver logado, redireciona automaticamente para `/landing`
///   (que decide se vai para o dashboard de aluno ou professor).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _goToLanding(BuildContext context) {
    // Usa microtask para evitar conflito de build
    Future.microtask(() {
      if (context.mounted) context.go('/landing');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          // ✅ Redireciona automaticamente se já estiver logado
          if (snap.connectionState == ConnectionState.active && snap.data != null) {
            _goToLanding(context);
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF6A6A), // rosa/laranja
                  Color(0xFF6A11CB), // roxo
                  Color(0xFF2575FC), // azul
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/poliedro-logo.png',
                        height: 80,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Título
                      const Text(
                        'Sistema Educacional',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: .2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtítulo
                      const Text(
                        'Acesse sua conta para continuar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Card de login
                      LoginCard(),

                      const SizedBox(height: 16),

                      // Loader sutil durante verificação de sessão
                      if (snap.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Opacity(
                            opacity: 0.8,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
