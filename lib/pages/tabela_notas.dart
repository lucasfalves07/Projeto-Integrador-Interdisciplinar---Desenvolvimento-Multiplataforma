// ==========================================================================
//  TABELA DE NOTAS — VERSÃO FINAL, 100% FUNCIONAL E COMPATÍVEL COM O FIRESTORE
//  - Professores lançam notas
//  - Aluno vê no Boletim em tempo real
//  - Dropdowns corrigidos (String tipado)
//  - Disciplina via disciplinaId (compatível com seu banco real)
//  - Edição e reedição de notas permitido
// ==========================================================================

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TabelaNotasPage extends StatefulWidget {
  const TabelaNotasPage({super.key});

  @override
  State<TabelaNotasPage> createState() => _TabelaNotasPageState();
}

class _TabelaNotasPageState extends State<TabelaNotasPage> {
  final _auth = FirebaseAuth.instance;

  String? _turmaSelecionada;
  String? _disciplinaSelecionada;

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];
  List<Map<String, dynamic>> _atividades = [];

  Map<String, String> _disciplinasNomes = {}; // <- TABELA DE DISCIPLINAS
  final Map<String, Map<String, double>> _notas = {};

  bool _carregando = false;
  bool _salvando = false;

  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  // ===============================================================
  //  BUSCAR TURMAS DO PROFESSOR
  // ===============================================================

  Future<void> _carregarTurmas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final perfil =
          (await FirebaseFirestore.instance.collection('users').doc(uid).get())
              .data()?['perfil']
              ?.toString();

      if (perfil != 'professor') {
        _mostrarErro("Somente professores podem acessar essa tela.");
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('turmas')
          .where('professorId', isEqualTo: uid)
          .get();

      _turmas = snap.docs.map((e) => {'id': e.id, ...e.data()}).toList();

      if (_turmas.isNotEmpty) {
        _turmaSelecionada = _turmas.first['id'] as String;
        await _carregarAlunosAtividadesENotas();
      }

      setState(() {});
    } catch (e) {
      _mostrarErro("Erro ao carregar turmas: $e");
    }
  }

  // ===============================================================
  //  CARREGAR DISCIPLINAS, ALUNOS, ATIVIDADES E NOTAS
  // ===============================================================

  Future<void> _carregarAlunosAtividadesENotas() async {
    final turmaId = _turmaSelecionada;
    if (turmaId == null) return;

    setState(() => _carregando = true);

    try {
      final db = FirebaseFirestore.instance;

      // ===== ALUNOS =====
      final alunosSnap =
          await db.collection('alunos').where('turmaId', isEqualTo: turmaId).get();

      _alunos = alunosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // ===== ATIVIDADES =====
      final atividadesSnap = await db
          .collection('atividades')
          .where('turmaId', isEqualTo: turmaId)
          .get();

      _atividades = atividadesSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // ===== DISCIPLINAS DA TURMA =====
      _disciplinasNomes.clear();

      for (final atv in _atividades) {
        final discId = atv['disciplinaId']?.toString();
        if (discId != null && discId.isNotEmpty) {
          final snap = await db.collection('disciplinas').doc(discId).get();
          _disciplinasNomes[discId] = snap.data()?['nome']?.toString() ?? "Disciplina";
        }
      }

      // ===== NOTAS =====
      QuerySnapshot<Map<String, dynamic>> notasSnap;

      try {
        notasSnap = await db
            .collection('notas')
            .where('turmaId', isEqualTo: turmaId)
            .get();
      } catch (_) {
        notasSnap = await db.collection('notas').get();
      }

      _notas.clear();

      for (final doc in notasSnap.docs) {
        final data = doc.data();

        final ra = data['alunoRa']?.toString() ?? "";
        final atvId = data['atividadeId']?.toString() ?? "";
        final nota = (data['nota'] ?? 0).toDouble();

        if (ra.isNotEmpty && atvId.isNotEmpty) {
          _notas.putIfAbsent(ra, () => {});
          _notas[ra]![atvId] = nota;
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      _mostrarErro("Erro ao carregar dados: $e");
    }

    if (mounted) setState(() => _carregando = false);
  }

  // ===============================================================
  //  BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff2f2f2),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const SizedBox(height: 12),
            _buildSelectors(),
            const SizedBox(height: 16),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainBody(_filtrarAtividades()),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  //  TOPO
  // ===============================================================

  Widget _buildTopBar() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(width: 40),
          Expanded(
            child: Center(
              child: Text(
                "Tabela de Notas",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  // ===============================================================
  //  SELECTORS
  // ===============================================================

  Widget _buildSelectors() {
    final disciplinas = _disciplinasNomes.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ======= TURMAS =======
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _turmaSelecionada,
              decoration: _decor('Turma'),
              items: _turmas
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text(t['nome'] ?? "Turma"),
                    ),
                  )
                  .toList(),
              onChanged: (String? v) async {
                setState(() {
                  _turmaSelecionada = v;
                  _disciplinaSelecionada = null;
                });
                await _carregarAlunosAtividadesENotas();
              },
            ),
          ),

          const SizedBox(width: 16),

          // ======= DISCIPLINAS =======
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _disciplinaSelecionada,
              decoration: _decor('Disciplina'),
              items: [
                const DropdownMenuItem<String>(
                  value: "",
                  child: Text("Todas"),
                ),
                ...disciplinas.map(
                  (d) => DropdownMenuItem<String>(
                    value: d.key,
                    child: Text(d.value),
                  ),
                ),
              ],
              onChanged: (String? v) {
                setState(() {
                  _disciplinaSelecionada = v == "" ? null : v;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // ===============================================================
  //  CORPO PRINCIPAL
  // ===============================================================

  Widget _buildMainBody(List<Map<String, dynamic>> atividades) {
    if (_alunos.isEmpty || atividades.isEmpty) {
      return const Center(child: Text("Nenhum dado encontrado."));
    }

    final width = max(1000.0, atividades.length * 160 + 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // TABELA
          Scrollbar(
            controller: _verticalController,
            child: SizedBox(
              height: 420,
              child: Scrollbar(
                controller: _horizontalController,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: _buildStudentTable(atividades),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          _buildClassSummary(atividades),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvarNotas,
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text("Salvar notas"),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ===============================================================
  //  TABELA
  // ===============================================================

  Widget _buildStudentTable(List<Map<String, dynamic>> atividades) {
    final headerCells = <Widget>[
      _header("RA"),
      _header("Aluno"),
      for (final atv in atividades)
        _header("${atv['titulo'] ?? 'Atividade'}\nPeso ${atv['peso'] ?? 1}"),
      _header("Média"),
      _header("Ponderada"),
      _header("Situação"),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(100),
          1: FixedColumnWidth(180),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.blue.shade50),
            children: headerCells,
          ),

          ..._alunos.map((al) {
            final ra = (al['ra'] ?? al['id']).toString();
            final nome = al['nome'] ?? "Aluno";

            final media = _mediaSimples(ra, atividades);
            final ponderada = _mediaPonderada(ra, atividades);
            final situacao = _status(ponderada);

            final row = <Widget>[
              _cell(Text(ra)),
              _cell(Text(nome)),
            ];

            for (final atv in atividades) {
              final id = atv['id'].toString();
              final nota = _notas[ra]?[id] ?? 0.0;

              row.add(
                _cell(
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: nota > 0 ? nota.toString() : "",
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        final parsed =
                            double.tryParse(v.replaceAll(",", ".")) ?? 0.0;
                        setState(() {
                          _notas.putIfAbsent(ra, () => {});
                          _notas[ra]![id] = parsed;
                        });
                      },
                    ),
                  ),
                ),
              );
            }

            row.add(_cell(Text(media.toStringAsFixed(2))));
            row.add(_cell(Text(ponderada.toStringAsFixed(2))));
            row.add(
              _cell(
                Text(
                  situacao,
                  style: TextStyle(color: _corSituacao(situacao)),
                ),
              ),
            );

            return TableRow(children: row);
          }),
        ],
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );

  Widget _cell(Widget c) => Padding(
        padding: const EdgeInsets.all(8),
        child: c,
      );

  // ===============================================================
  //  MÉDIAS
  // ===============================================================

  double _mediaSimples(String ra, List<Map<String, dynamic>> atv) {
    if (atv.isEmpty) return 0;

    double soma = 0;
    for (final a in atv) {
      final id = a['id'].toString();
      soma += _notas[ra]?[id] ?? 0.0;
    }

    return soma / atv.length;
  }

  double _mediaPonderada(String ra, List<Map<String, dynamic>> atv) {
    double soma = 0;
    double pesos = 0;

    for (final a in atv) {
      final id = a['id'].toString();
      final peso = (a['peso'] ?? 1).toDouble();
      final nota = _notas[ra]?[id] ?? 0.0;

      soma += nota * peso;
      pesos += peso;
    }

    return pesos == 0 ? 0 : soma / pesos;
  }

  Widget _buildClassSummary(List<Map<String, dynamic>> atv) {
    final simples = _mediaTurma(atv, _mediaSimples);
    final ponderada = _mediaTurma(atv, _mediaPonderada);

    return Row(
      children: [
        Expanded(child: _badge("Média da turma", simples, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _badge("Ponderada", ponderada, Colors.green)),
      ],
    );
  }

  Widget _badge(String label, double v, Color c) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            v.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  double _mediaTurma(
    List<Map<String, dynamic>> atv,
    double Function(String, List<Map<String, dynamic>>) fn,
  ) {
    if (_alunos.isEmpty) return 0;

    double soma = 0;

    for (final al in _alunos) {
      final ra = (al['ra'] ?? al['id']).toString();
      soma += fn(ra, atv);
    }

    return soma / _alunos.length;
  }

  // ===============================================================
  //  STATUS
  // ===============================================================

  String _status(double m) {
    if (m >= 7) return "Aprovado";
    if (m >= 4) return "Recuperação";
    return "Reprovado";
  }

  Color _corSituacao(String s) {
    switch (s) {
      case "Aprovado":
        return Colors.green;
      case "Recuperação":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // ===============================================================
  //  FILTRAR ATIVIDADES POR DISCIPLINA
  // ===============================================================

  List<Map<String, dynamic>> _filtrarAtividades() {
    if (_disciplinaSelecionada == null) return _atividades;

    return _atividades.where((a) {
      return a['disciplinaId']?.toString() == _disciplinaSelecionada;
    }).toList();
  }

  // ===============================================================
  //  SALVAR NOTAS
  // ===============================================================

  Future<void> _salvarNotas() async {
    setState(() => _salvando = true);

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _mostrarErro("Usuário não logado");
      setState(() => _salvando = false);
      return;
    }

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final aluno in _alunos) {
      final ra = (aluno['ra'] ?? aluno['id']).toString();
      final nome = aluno['nome'] ?? "Aluno";

      for (final atv in _atividades) {
        final idAtv = atv['id'].toString();
        final nota = _notas[ra]?[idAtv] ?? 0.0;

        final ref = db.collection("notas").doc("${idAtv}_$ra");

        batch.set(ref, {
          'atividadeId': idAtv,
          'alunoRa': ra,
          'alunoNome': nome,
          'nota': nota,
          'turmaId': _turmaSelecionada,
          'disciplinaId': atv['disciplinaId'],
          'professorId': uid,
          'bimestre': atv['bimestre'],
          'data': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notas salvas!")),
        );
      }
    } catch (e) {
      _mostrarErro("Erro ao salvar: $e");
    }

    if (mounted) setState(() => _salvando = false);
  }

  // ===============================================================
  //  ERROS
  // ===============================================================

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}