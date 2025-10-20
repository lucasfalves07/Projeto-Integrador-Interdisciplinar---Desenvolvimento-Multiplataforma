import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class DashboardProfessorPage extends StatefulWidget {
  const DashboardProfessorPage({super.key});

  @override
  State<DashboardProfessorPage> createState() =>
      _DashboardProfessorPageState();
}

class _DashboardProfessorPageState extends State<DashboardProfessorPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String professorName = "Carregando...";
  List<Map<String, dynamic>> turmas = [];
  List<Map<String, dynamic>> atividades = [];
  List<Map<String, dynamic>> materiais = [];
  List<Map<String, dynamic>> mensagens = [];
  double mediaGeral = 0.0;

  bool isLoading = true;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  /// Carrega todas as informações do professor
  Future<void> _carregarDados() async {
    if (currentUser == null) return;

    try {
      final userData = await _firestoreService.getUserByUid(currentUser!.uid);
      professorName = userData?["nome"] ?? "Professor(a)";

      turmas =
          await _firestoreService.listarTurmasDoProfessor(currentUser!.uid);

      atividades.clear();
      materiais.clear();
      mensagens.clear();
      double somaMedias = 0;
      int contadorTurmas = 0;

      for (var turma in turmas) {
        final turmaId = turma["id"];

        // Atividades
        final listaAtividades =
            await _firestoreService.buscarAtividadesPorTurma(turmaId);
        atividades.addAll(listaAtividades);

        // Materiais
        final listaMateriais =
            await _firestoreService.listarMateriaisPorTurma(turmaId);
        materiais.addAll(listaMateriais);

        // Mensagens
        final listaMensagens = await _buscarMensagensPorTurma(turmaId);
        mensagens.addAll(listaMensagens);

        // Calcular média geral da turma (com base nas notas)
        final notasSnap = await FirebaseFirestore.instance
            .collection("notas")
            .where("professorId", isEqualTo: currentUser!.uid)
            .get();

        if (notasSnap.docs.isNotEmpty) {
          double soma = 0;
          for (var n in notasSnap.docs) {
            soma += (n.data()["nota"] ?? 0).toDouble();
          }
          somaMedias += soma / notasSnap.docs.length;
          contadorTurmas++;
        }
      }

      mediaGeral =
          contadorTurmas == 0 ? 0 : (somaMedias / contadorTurmas).toDouble();

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e")),
        );
      }
    }
  }

  /// Busca mensagens no Firestore (fallback local)
  Future<List<Map<String, dynamic>>> _buscarMensagensPorTurma(
      String turmaId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("mensagens")
          .where("turmaId", isEqualTo: turmaId)
          .orderBy("timestamp", descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      debugPrint("Erro ao buscar mensagens: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width >= 1200) {
      crossAxisCount = 4;
    } else if (width >= 800) {
      crossAxisCount = 3;
    } else if (width >= 600) {
      crossAxisCount = 2;
    }

    final dashboardCards = [
      {
        "title": "Minhas Turmas",
        "description": "Gerencie suas turmas e alunos",
        "icon": Icons.group,
        "color": Colors.cyan,
        "count": "${turmas.length} turmas",
        "action": () => context.push('/turmas'),
      },
      {
        "title": "Materiais",
        "description": "Envie e organize materiais por turma",
        "icon": Icons.description,
        "color": Colors.orange,
        "count": "${materiais.length} materiais",
        "action": () => context.push('/materiais'),
      },
      {
        "title": "Atividades e Notas",
        "description": "Cadastre atividades e lance notas",
        "icon": Icons.school,
        "color": Colors.pink,
        "count": "${atividades.length} atividades",
        "action": () => context.push('/atividades'),
      },
      {
        "title": "Mensagens",
        "description": "Envie e receba mensagens com alunos",
        "icon": Icons.message,
        "color": Colors.blue,
        "count": "${mensagens.length} recentes",
        "action": () => context.push('/mensagens'),
      },
      {
        "title": "Desempenho das Turmas",
        "description": "Média geral das notas lançadas",
        "icon": Icons.bar_chart_rounded,
        "color": Colors.green,
        "count": "${mediaGeral.toStringAsFixed(1)} média",
        "action": () => context.push('/atividades'),
      },
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(theme),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _carregarDados,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickTabs(theme),
                          const SizedBox(height: 20),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dashboardCards.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 1.2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                            ),
                            itemBuilder: (context, i) {
                              final card = dashboardCards[i];
                              return _buildDashboardCard(theme, card);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ------------------------ HEADER ------------------------
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset("assets/poliedro-logo.png", height: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bem-vindo, $professorName",
                    style: theme.textTheme.titleLarge,
                  ),
                  const Text(
                    "Dashboard do Professor",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.push('/configuracoes'),
                icon: const Icon(Icons.settings, size: 18),
                label: const Text("Configurações"),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text("Sair"),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------ QUICK MENU ------------------------
  Widget _buildQuickTabs(ThemeData theme) {
    return Row(
      children: [
        _buildTabButton("Turmas", Icons.class_, 0, '/turmas', theme),
        const SizedBox(width: 8),
        _buildTabButton("Materiais", Icons.description, 1, '/materiais', theme),
        const SizedBox(width: 8),
        _buildTabButton("Atividades", Icons.school, 2, '/atividades', theme),
        const SizedBox(width: 8),
        _buildTabButton("Mensagens", Icons.message, 3, '/mensagens', theme),
      ],
    );
  }

  Widget _buildTabButton(
      String text, IconData icon, int index, String route, ThemeData theme) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: TextButton.icon(
        onPressed: () {
          setState(() => selectedTab = index);
          context.push(route);
        },
        icon: Icon(icon,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.8)),
        label: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor:
              isSelected ? Colors.orange : theme.colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ------------------------ CARD ------------------------
  Widget _buildDashboardCard(ThemeData theme, Map<String, dynamic> card) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: card["action"] as void Function(),
      child: Card(
        color: theme.cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: card["color"] as Color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      card["icon"] as IconData,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Text(
                    card["count"] as String,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                card["title"] as String,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                card["description"] as String,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
