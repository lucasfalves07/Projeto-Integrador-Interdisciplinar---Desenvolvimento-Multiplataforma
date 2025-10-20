// lib/router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------
// Páginas comuns
// -----------------------------
import 'pages/login.dart';
import 'pages/index.dart';
import 'pages/not_found.dart';
import 'pages/settings_page.dart';

// -----------------------------
// Dashboards
// -----------------------------
import 'pages/dashboard_aluno.dart';
import 'pages/dashboard_professor.dart';

// -----------------------------
// Professor (CRUD)
// -----------------------------
import 'pages/turmas_page.dart';
import 'pages/materiais_page.dart';
import 'pages/atividades_page.dart';
import 'pages/mensagens_page.dart';
import 'pages/alunos_page.dart';
import 'pages/tabela_notas.dart'; // ✅ novo módulo de notas detalhadas

// -----------------------------
// Aluno (visualizações)
// -----------------------------
import 'pages/materiais_aluno.dart';
import 'pages/notas_aluno.dart';
import 'pages/mensagens_aluno.dart';
import 'pages/calendario_aluno.dart';

/// ======================================================================
/// 🔒 Página de acesso negado
/// ======================================================================
class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final msg = message ?? 'Você não tem permissão para acessar esta página.';
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso negado')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================================================================
/// 🔁 Atualizador de rotas reativo ao estado do Firebase Auth
/// ======================================================================
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// ======================================================================
/// 🧩 RoleGuard — Protege rotas com base no tipo de usuário
/// ======================================================================
class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
  });

  final Set<String> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _GuardScaffold(
        icon: Icons.lock_person_outlined,
        title: 'Sessão necessária',
        subtitle: 'Faça login para acessar esta área.',
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _GuardScaffold(
            icon: Icons.hourglass_empty_outlined,
            title: 'Carregando…',
            subtitle: 'Verificando sua permissão.',
            progress: true,
          );
        }
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return const _GuardScaffold(
            icon: Icons.error_outline,
            title: 'Não foi possível validar seu perfil',
            subtitle: 'Tente novamente mais tarde.',
          );
        }

        final data = snap.data!.data() ?? <String, dynamic>{};
        final role = (data['role'] ?? data['tipo'] ?? '').toString().toLowerCase();

        if (allowedRoles.contains(role)) return child;
        return const ForbiddenPage();
      },
    );
  }
}

class _GuardScaffold extends StatelessWidget {
  const _GuardScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: Colors.black54),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              if (progress) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================================================================
/// 🚀 RoleLandingPage — Decide painel do usuário (aluno/professor)
/// ======================================================================
class RoleLandingPage extends StatelessWidget {
  const RoleLandingPage({super.key});

  Future<String> _resolveRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login';

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final role = (data['role'] ?? data['tipo'] ?? '').toString().toLowerCase();

      if (role == 'professor') return '/dashboard-professor';
      if (role == 'aluno') return '/dashboard-aluno';
      return '/dashboard-aluno';
    } catch (_) {
      return '/dashboard-aluno';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveRoute(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _GuardScaffold(
            icon: Icons.hourglass_bottom_outlined,
            title: 'Entrando…',
            subtitle: 'Direcionando para seu painel.',
            progress: true,
          );
        }

        final route = snap.data ?? '/dashboard-aluno';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(route);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

/// ======================================================================
/// 🧭 GoRouter principal
/// ======================================================================
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final path = state.uri.path;

    const publicRoutes = {'/login', '/', '/landing'};
    final isPublic = publicRoutes.contains(path);

    if (!isLoggedIn && !isPublic) return '/login';
    if (isLoggedIn && (path == '/login' || path == '/')) return '/landing';
    return null;
  },

  routes: [
    GoRoute(path: '/login', builder: (context, _) => const LoginPage()),
    GoRoute(path: '/', builder: (context, _) => const IndexPage()),
    GoRoute(path: '/landing', builder: (context, _) => const RoleLandingPage()),

    // -----------------------
    // Dashboards
    // -----------------------
    GoRoute(
      path: '/dashboard-aluno',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: DashboardAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/dashboard-professor',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: DashboardProfessorPage(),
      ),
    ),

    // -----------------------
    // Professor
    // -----------------------
    GoRoute(
      path: '/turmas',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: TurmasPage(),
      ),
    ),
    GoRoute(
      path: '/materiais',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: MateriaisPage(),
      ),
    ),
    GoRoute(
      path: '/atividades',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AtividadesPage(),
      ),
    ),
    GoRoute(
      path: '/mensagens',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: MensagensPage(),
      ),
    ),
    GoRoute(
      path: '/alunos',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AlunosPage(),
      ),
    ),
    GoRoute(
      path: '/tabela-notas', // ✅ nova rota de boletim/detalhes
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'professor'},
        child: TabelaNotasPage(),
      ),
    ),

    // -----------------------
    // Aluno
    // -----------------------
    GoRoute(
      path: '/aluno/materiais',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: MateriaisAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/notas',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: NotasAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/mensagens',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: MensagensAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/calendario',
      builder: (context, _) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: CalendarioAlunoPage(),
      ),
    ),

    // -----------------------
    // Comum
    // -----------------------
    GoRoute(
      path: '/configuracoes',
      builder: (context, _) => const SettingsPage(),
    ),
    GoRoute(
      path: '/forbidden',
      builder: (context, _) => const ForbiddenPage(),
    ),
  ],

  errorBuilder: (context, state) => const NotFoundPage(),
);
