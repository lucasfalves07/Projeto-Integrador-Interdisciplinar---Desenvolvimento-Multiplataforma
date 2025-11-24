// ===============================================================
// Dashboard Professor — VERSÃO FINAL + ADICIONADO CARD DE DESEMPENHO
// ===============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class DashboardProfessorPage extends StatefulWidget {
  const DashboardProfessorPage({super.key});

  @override
  State<DashboardProfessorPage> createState() => _DashboardProfessorPageState();
}

class _DashboardProfessorPageState extends State<DashboardProfessorPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  String professorNome = "Carregando...";
  List<Map<String, dynamic>> turmas = [];

  int countAlunos = 0;
  int countAtividades = 0;
  int countMateriais = 0;
  int countMensagens = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // ===========================================================
  // BOOTSTRAP — CARREGA TUDO
  // ===========================================================
  Future<void> _bootstrap() async {
    if (user == null) return;

    try {
      final db = FirebaseFirestore.instance;

      // -------- 1. BUSCAR NOME DO USERS --------
      final userSnap = await db.collection("users").doc(user!.uid).get();
      if (userSnap.exists) {
        professorNome = userSnap.data()?["nome"] ?? "Professor(a)";
      } else {
        // -------- 2. SE USERS NAO EXISTE, PEGAR PELA DISCIPLINA --------
        final discSnap = await db
            .collection("disciplinas")
            .where("professorId", isEqualTo: user!.uid)
            .limit(1)
            .get();

        if (discSnap.docs.isNotEmpty) {
          professorNome =
              discSnap.docs.first.data()["professor"] ?? "Professor(a)";
        }
      }

      // -------- TURMAS DO PROFESSOR --------
      final turmaSnap = await db
          .collection("turmas")
          .where("professorId", isEqualTo: user!.uid)
          .get();

      turmas = turmaSnap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
      final turmaIds = turmas.map((e) => e["id"].toString()).toList();

      // -------- CONTADORES --------
      countAlunos = await _contarAlunos(turmaIds);
      countAtividades = await _contarAtividades(turmaIds);
      countMateriais = await _contarMateriais(turmas);
      countMensagens = await _contarMensagens(turmaIds);

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e")),
        );
      }
    }
  }

  // ===========================================================
  // ALUNOS
  // ===========================================================
  Future<int> _contarAlunos(List<String> turmaIds) async {
    if (turmaIds.isEmpty) return 0;
    final db = FirebaseFirestore.instance;

    final snap = await db
        .collection("alunos")
        .where("turmaId", whereIn: turmaIds)
        .get();

    return snap.docs.length;
  }

  // ===========================================================
  // ATIVIDADES
  // ===========================================================
  Future<int> _contarAtividades(List<String> turmaIds) async {
    if (turmaIds.isEmpty) return 0;
    final db = FirebaseFirestore.instance;
    int total = 0;

    for (var i = 0; i < turmaIds.length; i += 10) {
      final slice =
          turmaIds.sublist(i, (i + 10 > turmaIds.length) ? turmaIds.length : i + 10);

      final snap = await db
          .collection("atividades")
          .where("turmaId", whereIn: slice)
          .get();

      total += snap.docs.length;
    }

    return total;
  }

  // ===========================================================
  // MATERIAIS
  // ===========================================================
  Future<int> _contarMateriais(List<Map<String, dynamic>> turmasDoProfessor) async {
    if (turmasDoProfessor.isEmpty) return 0;
    final db = FirebaseFirestore.instance;

    int total = 0;
    final disciplinaIds = <String>{};

    for (final turma in turmasDoProfessor) {
      final lista = (turma["disciplinas"] as List?) ?? [];
      for (final d in lista) {
        final id = (d["id"] ?? "").toString();
        if (id.isNotEmpty) disciplinaIds.add(id);
      }
    }

    for (final discId in disciplinaIds) {
      try {
        final matsDiretos = await db
            .collection("disciplinas")
            .doc(discId)
            .collection("materiais")
            .get();
        total += matsDiretos.docs.length;

        final topicosSnap = await db
            .collection("disciplinas")
            .doc(discId)
            .collection("topicos")
            .get();

        for (final t in topicosSnap.docs) {
          final mats = await t.reference.collection("materiais").get();
          total += mats.docs.length;
        }
      } catch (_) {}
    }

    return total;
  }

  // ===========================================================
  // MENSAGENS
  // ===========================================================
  Future<int> _contarMensagens(List<String> turmaIds) async {
    if (turmaIds.isEmpty || user == null) return 0;

    try {
      final db = FirebaseFirestore.instance;
      final professorId = user!.uid;
      final turmaSet = turmaIds.toSet();

      final snap = await db
          .collection("threads")
          .where("participantes", arrayContains: professorId)
          .get();

      int total = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final t = (data["turmaId"] ?? "").toString();
        if (turmaSet.contains(t)) total++;
      }

      return total;
    } catch (_) {
      return 0;
    }
  }

  // ===========================================================
  // BUILD
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _bootstrap,
                  child: SizedBox.expand(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Column(
                            children: [
                              _header(context),
                              _tabs(context),
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: _grid(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ===========================================================
  // HEADER
  // ===========================================================
  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: Row(
        children: [
          Flexible(
            child: Row(
              children: [
                Image.asset("assets/poliedro-logo.png", height: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bem-vindo(a), Prof. $professorNome",
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Painel do Professor",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push("/configuracoes"),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              context.go("/login");
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // TABS
  // ===========================================================
  Widget _tabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Wrap(
        spacing: 8,
        children: [
          _tab("Dashboard", selected: true, onTap: () {}),
          _tab("Turmas", onTap: () => context.push("/turmas")),
          _tab("Alunos", onTap: () => context.push("/alunos")),
        ],
      ),
    );
  }

  Widget _tab(String label,
      {bool selected = false, required VoidCallback onTap}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: selected ? Colors.blue.withOpacity(0.14) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ===========================================================
  // GRID + CARD DE DESEMPENHO ADICIONADO
  // ===========================================================
  Widget _grid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cross = width >= 1100 ? 3 : width >= 750 ? 2 : 1;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 1.8,
      ),
      children: [
        _card(
          color: Colors.teal,
          icon: Icons.group,
          title: "Minhas Turmas",
          subtitle: "Gerencie suas turmas",
          topRight: "${turmas.length} turmas",
          onTap: () => context.push("/turmas"),
        ),
        _card(
          color: Colors.purple,
          icon: Icons.people,
          title: "Alunos",
          subtitle: "Total de alunos",
          topRight: "$countAlunos alunos",
          onTap: () => context.push("/alunos"),
        ),
        _card(
          color: Colors.orange,
          icon: Icons.description,
          title: "Materiais",
          subtitle: "Conteúdos enviados",
          topRight: "$countMateriais materiais",
          onTap: () => context.push("/materiais"),
        ),
        _card(
          color: Colors.pink,
          icon: Icons.assignment,
          title: "Atividades",
          subtitle: "Provas e tarefas",
          topRight: "$countAtividades atividades",
          onTap: () => context.push("/atividades"),
        ),
        _card(
          color: Colors.green,
          icon: Icons.edit_note,
          title: "Lançar Notas",
          subtitle: "Notas e médias",
          topRight: "${turmas.length} turmas",
          onTap: () => context.push("/tabela_notas"),
        ),
        _card(
          color: Colors.blue,
          icon: Icons.chat_bubble_outline,
          title: "Mensagens",
          subtitle: "Interaja com alunos",
          topRight: "$countMensagens recentes",
          onTap: () => context.push("/mensagens"),
        ),

        // ================================================
        // 🎉 NOVO CARD ADICIONADO — DESEMPENHO DETALHADO
        // ================================================
        _card(
          color: Colors.indigo,
          icon: Icons.bar_chart,
          title: "Desempenho",
          subtitle: "Médias e análises",
          topRight: "Módulo",
          onTap: () => context.push("/desempenho_detalhado_page"),
        ),
      ],
    );
  }

  // ===========================================================
  // CARD
  // ===========================================================
  Widget _card({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required String topRight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  Flexible(
                    child: Text(
                      topRight,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}