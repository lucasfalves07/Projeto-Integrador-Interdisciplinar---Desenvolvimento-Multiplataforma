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
import 'pages/admin_tools.dart';
import 'pages/alunos_page.dart';
import 'pages/boletim_page.dart';
import 'pages/admin_usuarios.dart';
import 'pages/desempenho_detalhado_page.dart';
import 'pages/tabela_notas.dart';

// -----------------------------
// Aluno (visualizações)
// -----------------------------
import 'pages/materiais_aluno.dart';
import 'pages/mensagens_aluno.dart';
import 'pages/calendario_aluno.dart';
import 'pages/atividades_aluno.dart';

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
              const Icon(Icons.lock_outline, size: 80, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================================================================
/// 🔁 Atualizador reativo (listener de auth)
/// ======================================================================
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// ======================================================================
/// 🧩 RoleGuard — Protege rotas por tipo de usuário
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
      return const ForbiddenPage(message: "Faça login para continuar.");
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snap.data!.data();
        if (data == null) {
          return const ForbiddenPage(message: "Perfil não encontrado.");
        }

        final role = (data['role'] ?? data['tipo'] ?? data['perfil'] ?? 'aluno')
            .toString()
            .trim()
            .toLowerCase();

        return allowedRoles.contains(role)
            ? child
            : const ForbiddenPage(message: "Acesso restrito a outro perfil.");
      },
    );
  }
}

/// ======================================================================
/// 🚀 RoleLandingPage — Decide dashboard aluno/professor
/// ======================================================================
class RoleLandingPage extends StatelessWidget {
  const RoleLandingPage({super.key});

  Future<String> _resolve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = (doc.data()?['role'] ?? doc.data()?['tipo'] ?? 'aluno')
          .toString()
          .toLowerCase();

      if (role == 'professor') return '/dashboard-professor';
      return '/dashboard-aluno';
    } catch (_) {
      return '/dashboard-aluno';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _resolve(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(snap.data.toString());
        });

        return const SizedBox.shrink();
      },
    );
  }
}

/// ======================================================================
/// 🚦 GoRouter Definitivo
/// ======================================================================
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final logged = user != null;
    final path = state.uri.path;

    const public = {'/', '/login'};

    if (!logged && !public.contains(path)) return '/login';
    if (logged && path == '/login') return '/landing';

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (_, __) => const IndexPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/landing', builder: (_, __) => const RoleLandingPage()),

    // =======================
    // Dashboards
    // =======================
    GoRoute(
      path: '/dashboard-aluno',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: DashboardAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/dashboard-professor',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: DashboardProfessorPage(),
      ),
    ),

    // =======================
    // Professor
    // =======================
    GoRoute(
      path: '/turmas',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: TurmasPage(),
      ),
    ),
    GoRoute(
      path: '/materiais',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: MateriaisPage(),
      ),
    ),
    GoRoute(
      path: '/atividades',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AtividadesPage(),
      ),
    ),
    GoRoute(
      path: '/mensagens',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: MensagensPage(),
      ),
    ),
    GoRoute(
      path: '/tabela_notas',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: TabelaNotasPage(),
      ),
    ),
    GoRoute(
      path: '/desempenho_detalhado_page',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: DesempenhoDetalhadoPage(),
      ),
    ),
    GoRoute(
      path: '/alunos',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AlunosPage(),
      ),
    ),
    GoRoute(
      path: '/admin-tools',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AdminToolsPage(),
      ),
    ),
    GoRoute(
      path: '/admin/usuarios',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'professor'},
        child: AdminUsuariosPage(),
      ),
    ),

    // =======================
    // Aluno
    // =======================
    GoRoute(
      path: '/aluno/materiais',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: MateriaisAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/notas',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: BoletimPage(),   // ✔ CORRIGIDO — agora abre o boletim certo
      ),
    ),
    GoRoute(
      path: '/aluno/atividades',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: AtividadesAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/mensagens',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: MensagensAlunoPage(),
      ),
    ),
    GoRoute(
      path: '/aluno/calendario',
      builder: (_, __) => const RoleGuard(
        allowedRoles: {'aluno'},
        child: CalendarioAlunoPage(),
      ),
    ),
    // =======================
    // Comum
    // =======================
    GoRoute(path: '/boletim', builder: (_, __) => const BoletimPage()),
    GoRoute(path: '/configuracoes', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenPage()),
  ],

  errorBuilder: (_, __) => const NotFoundPage(),
);