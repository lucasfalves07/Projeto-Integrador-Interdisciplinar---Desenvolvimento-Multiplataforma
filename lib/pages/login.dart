import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../components/cards/index.dart';

/// =================================================================
/// LOGIN PAGE — Sistema Poliedro
/// =================================================================
/// Regras de acesso:
///  • Professores → email @sistemapoliedro.com.br
///  • Alunos      → email @alunosistemapoliedro.com.br
///
/// A página redireciona automaticamente se o usuário já estiver logado.
///
/// A validação do domínio é feita no LoginCard.
/// =================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _redirected = false;

  /// ================================================================
  /// 🔹 Redirecionamento seguro (evita loops do StreamBuilder)
  /// ================================================================
  void _redirectToLanding() {
    if (_redirected || !mounted) return;
    _redirected = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/landing');
    });
  }

  /// ================================================================
  /// 🔹 UI
  /// ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          final user = snap.data;

          // Usuário já possui sessão → envia para rota de decisão (Index/Landing)
          if (snap.connectionState == ConnectionState.active && user != null) {
            _redirectToLanding();
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFF6A6A),
                  Color(0xFF6A11CB),
                  Color(0xFF2575FC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ====================================================
                      // LOGO
                      // ====================================================
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: Image.asset(
                          'assets/poliedro-logo.png',
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            size: 90,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ====================================================
                      // TÍTULO
                      // ====================================================
                      const Text(
                        'Sistema Educacional Poliedro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: .3,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ====================================================
                      // SUBTÍTULO
                      // ====================================================
                      const Text(
                        'Acesse sua conta para continuar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ====================================================
                      // CARTÃO DE LOGIN
                      // ====================================================
                      const LoginCard(),

                      const SizedBox(height: 20),

                      // Loader enquanto o Firebase sincroniza sessão
                      if (snap.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.only(top: 10.0),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.white30,
                            color: Colors.white,
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