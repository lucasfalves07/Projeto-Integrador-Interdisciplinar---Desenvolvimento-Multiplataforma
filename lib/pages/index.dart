import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Página inicial de decisão de rota (splash router)
/// - Verifica autenticação do Firebase.
/// - Busca o perfil do usuário no Firestore.
/// - Redireciona automaticamente para o dashboard correto:
///     • /dashboard-professor
///     • /dashboard-aluno
/// - Se não logado, envia para /login.
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
    _decidirRota();
  }

  /// Função principal que decide o destino do usuário
  Future<void> _decidirRota() async {
    // Pequeno atraso para garantir que o contexto esteja pronto
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final user = _auth.currentUser;

      // Caso não esteja logado
      if (user == null) {
        if (!mounted) return;
        context.go('/login');
        return;
      }

      // Busca o documento do usuário no Firestore
      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        setState(() {
          _error =
              'Seu perfil (users/${user.uid}) não foi encontrado no Firestore.\n'
              'Peça para um professor ou administrador configurar seu usuário.';
        });
        return;
      }

      final data = doc.data() ?? {};

      // Verifica o campo "tipo" ou "role" (aceita ambos)
      String tipo = (data['tipo'] ?? data['role'] ?? '').toString().toLowerCase().trim();

      // Se o campo estiver ausente, tenta inferir pelo e-mail (fallback)
      if (tipo.isEmpty) {
        final email = user.email ?? '';
        if (email.contains('prof') || email.contains('teacher')) {
          tipo = 'professor';
        } else {
          tipo = 'aluno';
        }
      }

      if (!mounted) return;

      // Redireciona conforme o tipo identificado
      switch (tipo) {
        case 'professor':
          context.go('/dashboard-professor');
          break;

        case 'aluno':
          context.go('/dashboard-aluno');
          break;

        default:
          setState(() {
            _error = '''
Campo "tipo/role" inválido no seu perfil: "$tipo".
Verifique no Firestore se está definido como "aluno" ou "professor".
            ''';
          });
      }
    } catch (e) {
      setState(() {
        _error = '⚠️ Falha ao decidir rota: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se deu erro, mostra mensagem amigável
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível abrir seu painel',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.logout),
                    label: const Text('Voltar para o login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Tela de carregamento enquanto decide a rota
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 16),
            Text(
              'Carregando seu ambiente...',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
