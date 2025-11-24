// ======================================================================
//  NOTAS_ALUNO.DART — VERSÃO FINAL (IGUAL À TABELA DO PROFESSOR)
//  - Tabela completa com atividade, nota, peso, máx, disciplina
//  - Média da disciplina (automática)
//  - Situação (Aprovado / Recuperação / Reprovado)
//  - Sincronizado 100% com o banco da Duda
// ======================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotasAlunoPage extends StatefulWidget {
  const NotasAlunoPage({super.key});

  @override
  State<NotasAlunoPage> createState() => _NotasAlunoPageState();
}

class _NotasAlunoPageState extends State<NotasAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;

  String alunoNome = "";
  String alunoRA = "";
  String turmaNome = "";
  String turmaId = "";

  List<Map<String, dynamic>> _atividades = [];
  List<Map<String, dynamic>> _notas = [];

  Map<String, double> _mediaPorDisciplina = {};
  Map<String, String> _discSituacao = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ============================================================
  //  CARREGA TUDO
  // ============================================================
  Future<void> _load() async {
    try {
      setState(() => _loading = true);

      final user = _auth.currentUser;
      if (user == null) throw "Usuário não autenticado.";

      // user
      final u = await _db.collection("users").doc(user.uid).get();
      final ra = (u["ra"] ?? "").toString();
      final nome = (u["nome"] ?? "").toString();

      final turmas = (u["turmas"] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (turmas.isEmpty) throw "Nenhuma turma vinculada";

      final tId = turmas.first;
      final tSnap = await _db.collection("turmas").doc(tId).get();
      final tNome = (tSnap["nome"] ?? tId).toString();

      // atividades dessa turma
      final atvSnap = await _db
          .collection("atividades")
          .where("turmaId", isEqualTo: tId)
          .get();

      final atividades = atvSnap.docs.map((d) => {"id": d.id, ...d.data()}).toList();

      // notas do aluno dessa turma
      final notasSnap = await _db
          .collection("notas")
          .where("alunoRa", isEqualTo: ra)
          .where("turmaId", isEqualTo: tId)
          .get();

      final notas = notasSnap.docs.map((d) => {"id": d.id, ...d.data()}).toList();

      // calcular médias e situação
      final mediaDisc = <String, double>{};
      final situacaoDisc = <String, String>{};

      final group = <String, List<double>>{};

      for (var n in notas) {
        final atvId = n["atividadeId"];
        final nota = (n["nota"] as num?)?.toDouble() ?? 0;

        final atv = atividades.firstWhere(
          (a) => a["id"] == atvId,
          orElse: () => {},
        );

        if (atv.isEmpty) continue;

        final discId = atv["disciplinaId"].toString();
        group.putIfAbsent(discId, () => []);
        group[discId]!.add(nota);
      }

      group.forEach((discId, lista) {
        double m = 0;
        if (lista.isNotEmpty) {
          m = lista.reduce((a, b) => a + b) / lista.length;
        }
        mediaDisc[discId] = m;

        // situação
        if (m >= 6) {
          situacaoDisc[discId] = "Aprovado";
        } else if (m >= 4) {
          situacaoDisc[discId] = "Recuperação";
        } else {
          situacaoDisc[discId] = "Reprovado";
        }
      });

      if (!mounted) return;
      setState(() {
        alunoNome = nome;
        alunoRA = ra;
        turmaId = tId;
        turmaNome = tNome;
        _atividades = atividades;
        _notas = notas;
        _mediaPorDisciplina = mediaDisc;
        _discSituacao = situacaoDisc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  }

  // ============================================================
  //  TELA
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Minhas Notas"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _body(),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerCard(),
          const SizedBox(height: 20),
          _tabelaNotasAluno(),
        ],
      ),
    );
  }

  // ============================================================
  //  CARD DO ALUNO
  // ============================================================
  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.indigo.shade100,
              child: const Icon(Icons.person, size: 40, color: Colors.indigo),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alunoNome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text("RA: $alunoRA", style: const TextStyle(color: Colors.black54)),
                Text(turmaNome, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  TABELA IGUAL DO PROFESSOR
  // ============================================================
  Widget _tabelaNotasAluno() {
    if (_atividades.isEmpty) {
      return const Center(
        child: Text("Nenhuma atividade cadastrada."),
      );
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text("Atividade")),
        DataColumn(label: Text("Nota")),
        DataColumn(label: Text("Peso")),
        DataColumn(label: Text("Máx")),
        DataColumn(label: Text("Disciplina")),
        DataColumn(label: Text("Média")),
        DataColumn(label: Text("Situação")),
      ],
      rows: _atividades.map((a) {
        final nota = _notas.firstWhere(
          (n) => n["atividadeId"] == a["id"],
          orElse: () => {},
        );

        final valor = nota.isEmpty ? null : (nota["nota"] as num?)?.toDouble();
        final notaTxt = valor == null ? "-" : valor.toStringAsFixed(1);

        final peso = (a["peso"] as num?)?.toDouble() ?? 1;
        final max = (a["max"] as num?)?.toDouble() ?? 10;

        final discNome = (a["disciplinaNome"] ?? "-").toString();
        final discId = a["disciplinaId"].toString();

        final media = _mediaPorDisciplina[discId] ?? 0;
        final situacao = _discSituacao[discId] ?? "-";

        return DataRow(
          cells: [
            DataCell(Text(a["titulo"] ?? "Atividade")),
            DataCell(Text(
              notaTxt,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valor == null
                    ? Colors.grey
                    : valor >= 6
                        ? Colors.green
                        : Colors.red,
              ),
            )),
            DataCell(Text(peso.toString())),
            DataCell(Text(max.toString())),
            DataCell(Text(discNome)),
            DataCell(Text(media.toStringAsFixed(1))),
            DataCell(Text(
              situacao,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: situacao == "Aprovado"
                    ? Colors.green
                    : situacao == "Recuperação"
                        ? Colors.orange
                        : Colors.red,
              ),
            )),
          ],
        );
      }).toList(),
    );
  }
}