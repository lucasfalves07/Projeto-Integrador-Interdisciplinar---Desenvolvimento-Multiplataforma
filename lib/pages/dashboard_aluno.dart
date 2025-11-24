// ===============================================================
// Dashboard Aluno — Versão Final + Correções Responsivas (SEM OVERFLOW)
// ===============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardAlunoPage extends StatefulWidget {
  const DashboardAlunoPage({super.key});

  @override
  State<DashboardAlunoPage> createState() => _DashboardAlunoPageState();
}

class _DashboardAlunoPageState extends State<DashboardAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String alunoNome = "Carregando...";
  String alunoRA = "";
  String turmaNome = "";
  String? turmaId;

  List<Map<String, dynamic>> atividades = [];
  List<Map<String, dynamic>> mensagens = [];
  List<Map<String, dynamic>> notas = [];

  double mediaGeral = 0.0;
  int pendentes = 0;
  int novasMensagens = 0;

  bool loading = true;
  int bottomIndex = 0;
  bool _jaAvisouPermissao = false;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  // =======================================================
  Future<void> _carregarTudo() async {
    if (!mounted) return;
    setState(() => loading = true);

    final user = currentUser;
    if (user == null) {
      setState(() => loading = false);
      return;
    }

    DocumentSnapshot<Map<String, dynamic>>? alunoSnap;

    try {
      final doc = await _db.collection("users").doc(user.uid).get();
      if (doc.exists) alunoSnap = doc;
    } catch (e) {
      _mostrarErro("Erro ao acessar perfil do usuário.");
    }

    try {
      final alunoSnap = await _db.collection("users").doc(user.uid).get();
      final aluno = alunoSnap.data() ?? {};

      alunoNome = aluno["nome"] ?? "Aluno";
      alunoRA = aluno["ra"]?.toString() ?? "";

      final turmasAluno = (aluno["turmas"] ?? []).cast<String>();
      if (turmasAluno.isEmpty) throw Exception("Aluno sem turma.");

      turmaId = turmasAluno.first;

      final turmaSnap = await _db.collection("turmas").doc(turmaId).get();
      turmaNome = turmaSnap.data()?["nome"] ?? "";
    } on FirebaseException catch (e) {
      _mostrarErro(
        e.code == "permission-denied"
            ? "Sem permissão para carregar seus dados."
            : "Não foi possível carregar seu perfil.",
        e,
      );
      alunoNome = "Aluno";
      alunoRA = "";
      turmaId = null;
      turmaNome = "";
      setState(() => loading = false);
      return;
    } catch (e) {
      _mostrarErro("Erro: $e");
      alunoNome = "Aluno";
      alunoRA = "";
      turmaId = null;
      turmaNome = "";
      setState(() => loading = false);
      return;
    }

    atividades = await _carregarLista(
      _db.collection("atividades").where("turmaId", isEqualTo: turmaId),
      contexto: "atividades da turma",
    );

    notas = await _carregarLista(
      _db.collection("notas").where("alunoRa", isEqualTo: alunoRA),
      contexto: "suas notas",
    );

    mensagens = await _carregarLista(
      _db.collection("threads").where("alunoRa", isEqualTo: alunoRA),
      contexto: "mensagens",
    );

    mediaGeral = _calcMedia();
    pendentes = _calcPendentes();
    novasMensagens = mensagens.length;

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<List<Map<String, dynamic>>> _carregarLista(
    Query<Map<String, dynamic>> query, {
    required String contexto,
  }) async {
    try {
      final snap = await query.get();
      return snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } on FirebaseException catch (e) {
      _mostrarErro(
        e.code == "permission-denied"
            ? "Sem permissão para acessar $contexto."
            : "Erro ao carregar $contexto.",
        e,
      );
      return [];
    } catch (_) {
      return [];
    }
  }

  void _mostrarErro(String mensagem, [FirebaseException? e]) {
    if (!mounted) return;
    if (e != null && e.code == "permission-denied") {
      if (_jaAvisouPermissao) return;
      _jaAvisouPermissao = true;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  double _calcMedia() {
    if (notas.isEmpty) return 0;
    final soma = notas.fold<double>(
      0.0,
      (a, n) => a + ((n["nota"] as num?)?.toDouble() ?? 0.0),
    );
    return soma / notas.length;
  }

  int _calcPendentes() {
    if (atividades.isEmpty) return 0;
    final realizadas = notas.map((n) => n["atividadeId"]).toSet();
    int count = 0;
    final agora = DateTime.now();

    for (final a in atividades) {
      final prazo = (a["prazo"] as Timestamp?)?.toDate() ??
          (a["data"] as Timestamp?)?.toDate();

      if (prazo != null &&
          !realizadas.contains(a["id"]) &&
          prazo.isAfter(agora)) {
        count++;
      }
    }
    return count;
  }

  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f7fb),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarTudo,
              child: ListView(
                children: [
                  _header(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _metricasGrid(),
                        const SizedBox(height: 20),
                        _atalhos(),
                        const SizedBox(height: 20),
                        _proximasAtividades(),
                        const SizedBox(height: 20),
                        _mensagensRecentes(),
                      ],
                    ),
                  )
                ],
              ),
            ),
      bottomNavigationBar: _bottom(),
    );
  }

  // =======================================================
  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Image.asset("assets/poliedro-logo.png", height: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alunoNome,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                Text("RA: $alunoRA • $turmaNome",
                    style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarTudo,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) context.go("/login");
            },
          ),
        ],
      ),
    );
  }

  // =======================================================
  Widget _metricasGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.3,
      children: [
        _metricCard("Média Geral", mediaGeral.toStringAsFixed(1),
            Colors.teal.shade700),
        _metricCard(
            "Pendentes", pendentes.toString(), Colors.orange.shade700),
        _metricCard("Mensagens", novasMensagens.toString(),
            Colors.blue.shade700),
      ],
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.analytics, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(color: Colors.black54)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================
  Widget _atalhos() {
    Widget item(IconData ic, String title, String subtitle, String route) {
      return InkWell(
        onTap: () => context.push(route),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(ic, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        item(Icons.menu_book, "Materiais", "Conteúdos", "/aluno/materiais"),
        item(Icons.grading_rounded, "Minhas Notas", "Boletim",
            "/aluno/notas"),
        item(Icons.chat, "Mensagens", "Chat", "/aluno/mensagens"),
        item(Icons.event, "Calendário", "Prazos", "/aluno/calendario"),
      ],
    );
  }

  // =======================================================
  Widget _proximasAtividades() {
    final proximas = atividades.where((a) {
      final prazo = (a["prazo"] as Timestamp?)?.toDate() ??
          (a["data"] as Timestamp?)?.toDate();
      return prazo != null && prazo.isAfter(DateTime.now());
    }).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Próximas Atividades",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (proximas.isEmpty)
          const Card(
            child: ListTile(title: Text("Nenhuma atividade pendente 🎉")),
          )
        else
          ...proximas.map((a) {
            final prazo = ((a["prazo"] ?? a["data"]) as Timestamp).toDate();
            final prazoStr = DateFormat("dd/MM").format(prazo);

            return Card(
              child: ListTile(
                title: Text(a["titulo"] ?? "Atividade"),
                subtitle: Text("Prazo: $prazoStr"),
                trailing: Text(a["tipo"] ?? ""),
              ),
            );
          })
      ],
    );
  }

  // =======================================================
  Widget _mensagensRecentes() {
    final ultimas = mensagens.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Mensagens Recentes",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (ultimas.isEmpty)
          const Card(
              child: ListTile(title: Text("Nenhuma mensagem 📭")))
        else
          ...ultimas.map((m) {
            final ultima = m["lastMessage"] ?? "";
            final ts = m["updatedAt"];
            final dt = ts is Timestamp ? ts.toDate() : null;
            final dtStr =
                dt != null ? DateFormat("dd/MM").format(dt) : "-";

            return Card(
              child: ListTile(
                title: const Text("Professor",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  ultima,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(dtStr),
              ),
            );
          })
      ],
    );
  }

  // =======================================================
  Widget _bottom() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: bottomIndex,
      onTap: (i) {
        setState(() => bottomIndex = i);
        switch (i) {
          case 1:
            context.push("/aluno/calendario");
            break;
          case 2:
            context.push("/aluno/atividades");
            break;
          case 3:
            context.push("/aluno/mensagens");
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard), label: "Painel"),
        BottomNavigationBarItem(
            icon: Icon(Icons.event_note), label: "Calendário"),
        BottomNavigationBarItem(
            icon: Icon(Icons.checklist), label: "Tarefas"),
        BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline), label: "Mensagens"),
      ],
    );
  }
}