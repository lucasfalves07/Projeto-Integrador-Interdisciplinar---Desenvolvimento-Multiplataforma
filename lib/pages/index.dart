import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ============================================================================
/// INDEX PAGE — Splash que decide automaticamente o tipo de usuário e envia
/// para o dashboard correto.
/// ============================================================================
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _error;

  @override
  void initState() {
    super.initState();
    _resolverRota();
  }

  /// ==========================================================================
  /// 🔹 Resolve automaticamente se é aluno ou professor
  /// ==========================================================================
  Future<void> _resolverRota() async {
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        context.go('/login');
        return;
      }

      // Tenta buscar perfil no Firestore
      final doc = await _db.collection('users').doc(user.uid).get();

      String role = '';

      if (doc.exists) {
        final data = doc.data() ?? {};
        role = (data['role'] ??
                data['tipo'] ??
                data['perfil'] ??
                data['userType'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
      }

      // Caso o Firestore não tenha role definida, tenta inferir pelo email
      if (role.isEmpty) {
        final email = user.email ?? '';

        if (email.contains('@sistemapoliedro')) {
          role = 'professor';
        } else if (email.contains('@alunosistemapoliedro')) {
          role = 'aluno';
        } else {
          // Último fallback → considera aluno
          role = 'aluno';
        }
      }

      if (!mounted) return;

      // Envio para dashboard correto
      if (role == 'professor') {
        context.go('/dashboard-professor');
        return;
      }
      if (role == 'aluno') {
        context.go('/dashboard-aluno');
        return;
      }

      // Se caiu aqui, role inválido
      setState(() {
        _error = '''
O valor do seu campo "role/tipo" é inválido: "$role".

Defina no Firestore como:
• aluno
• professor

(users/${user.uid})
''';
      });
    } catch (e) {
      setState(() {
        _error =
            '⚠️ Não foi possível decidir automaticamente seu painel.\nErro: $e';
      });
    }
  }

  /// ==========================================================================
  /// 🔹 UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 50, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    "Não foi possível abrir seu painel",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text("Voltar ao Login"),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Tela de carregamento
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text(
              "Carregando seu ambiente...",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}