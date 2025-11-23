// ---------------------------------------------------------------
//  BOLETIM DO PROFESSOR — VERSÃO FINAL, OTIMIZADA E COMPATÍVEL
// ---------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/export_boletim_pdf.dart';

class BoletimProfessorPage extends StatefulWidget {
  const BoletimProfessorPage({super.key});

  @override
  State<BoletimProfessorPage> createState() => _BoletimProfessorPageState();
}

class _BoletimProfessorPageState extends State<BoletimProfessorPage> {
  bool _carregando = false;
  bool _exportando = false;
  String? _erro;

  String? _turmaSelecionada;
  String _turmaNome = '';

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];

  final Map<String, Map<String, dynamic>> _atividades = {};
  final Map<String, Map<String, dynamic>> _disciplinas = {};

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  // ============================================================  
  // 🔹 Carregar TURMAS
  // ============================================================
  Future<void> _carregarTurmas() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final snap = await FirebaseFirestore.instance.collection('turmas').get();
      _turmas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (_turmas.isNotEmpty) {
        _turmaSelecionada = _turmas.first['id'];
        _turmaNome = _turmas.first['nome'] ?? '';
        await _carregarBoletimTurma();
      }
    } catch (e) {
      _erro = 'Erro ao carregar turmas: $e';
    }

    setState(() => _carregando = false);
  }

  // ============================================================  
  // 🔹 Carregar alunos e atividades da turma  
  // ============================================================
  Future<void> _carregarBoletimTurma() async {
    if (_turmaSelecionada == null) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    _alunos.clear();
    _atividades.clear();
    _disciplinas.clear();

    try {
      final db = FirebaseFirestore.instance;

      // 🔹 ALUNOS
      final alunosSnap = await db
          .collection('alunos')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();

      _alunos = alunosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // 🔹 ATIVIDADES
      final atvSnap = await db
          .collection('atividades')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();

      for (final d in atvSnap.docs) {
        _atividades[d.id] = {'id': d.id, ...d.data()};
      }

      // 🔹 DISCIPLINAS
      final discIds = _atividades.values
          .map((a) => (a['disciplinaId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (discIds.isNotEmpty) {
        for (int i = 0; i < discIds.length; i += 10) {
          final fatia = discIds.sublist(i, min(i + 10, discIds.length));
          final ds = await db
              .collection('disciplinas')
              .where(FieldPath.documentId, whereIn: fatia)
              .get();

          for (final d in ds.docs) {
            _disciplinas[d.id] = {'id': d.id, ...d.data()};
          }
        }
      }
    } catch (e) {
      _erro = 'Erro ao carregar boletim: $e';
    }

    setState(() => _carregando = false);
  }

  // ============================================================  
  // 🔹 Média Ponderada  
  // ============================================================
  double _mediaGeralAluno(List<Map<String, dynamic>> notas) {
    double soma = 0, peso = 0;

    for (final n in notas) {
      final atv = _atividades[n['atividadeId']];
      if (atv == null) continue;

      final p = (atv['peso'] ?? 1).toDouble();
      final nota = (n['nota'] ?? 0).toDouble();

      soma += nota * p;
      peso += p;
    }

    return peso == 0 ? 0 : soma / peso;
  }

  String _status(double m) {
    if (m >= 7) return 'Aprovado';
    if (m >= 5) return 'Recuperação';
    return 'Reprovado';
  }

  Color _corStatus(String s) {
    switch (s) {
      case 'Aprovado':
        return const Color(0xFF22C55E);
      case 'Recuperação':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  // ============================================================  
  // 🔹 EXPORTAR PDF — BOLETIM DA TURMA  
  // ============================================================
  Future<void> _exportarBoletimTurma() async {
    if (_exportando || _turmaSelecionada == null) return;

    setState(() => _exportando = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Gerando PDF da turma...")),
    );

    try {
      final db = FirebaseFirestore.instance;
      final Map<String, double> medias = {};
      final Map<String, String> status = {};

      for (final aluno in _alunos) {
        final ra = aluno['ra'] ?? aluno['id'];

        final snap = await db
            .collection('notas')
            .where('alunoRA', isEqualTo: ra)
            .get();

        final notas = snap.docs.map((d) => d.data()).toList();
        final media = _mediaGeralAluno(notas);

        medias[ra] = media;
        status[ra] = _status(media);
      }

      await ExportBoletimPDF.gerarPDF(
        alunoNome: "Boletim da Turma",
        alunoRA: "-",
        turmaNome: _turmaNome.isEmpty ? _turmaSelecionada! : _turmaNome,
        mediasPorDisciplinaBim: {},
        mediaFinalPorDisciplina: medias,
        statusPorDisciplina: status,
        disciplinasNomes: {},
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PDF gerado!')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro: $e")));
    }

    setState(() => _exportando = false);
  }

  // ============================================================  
  // 🔹 UI  
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_erro != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _erro!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Boletim da Turma"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportando ? null : _exportarBoletimTurma,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarBoletimTurma,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _dropdownTurmas(),
            const SizedBox(height: 12),
            Expanded(child: _tabelaBoletim()),
          ],
        ),
      ),
    );
  }

  // ============================================================  
  // 🔹 Dropdown — Turmas  
  // ============================================================
  Widget _dropdownTurmas() {
    return DropdownButtonFormField<String>(
      value: _turmaSelecionada,
      decoration: const InputDecoration(
        labelText: "Turma",
        border: OutlineInputBorder(),
      ),
      items: _turmas
          .map((t) => DropdownMenuItem(
                value: t['id'],
                child: Text(t['nome'] ?? t['id']),
              ))
          .toList(),
      onChanged: (v) async {
        setState(() {
          _turmaSelecionada = v;
          _turmaNome = (_turmas.firstWhere(
                    (t) => t['id'] == v,
                    orElse: () => {'nome': v})['nome'] ??
                v)
            .toString();
        });
        await _carregarBoletimTurma();
      },
    );
  }

  // ============================================================  
  // 🔹 Tabela — Lista de alunos com notas  
  // ============================================================
  Widget _tabelaBoletim() {
    if (_alunos.isEmpty) {
      return const Center(child: Text("Nenhum aluno nesta turma."));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _carregarNotasAlunos(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final alunos = snap.data!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('RA')),
              DataColumn(label: Text('Aluno')),
              DataColumn(label: Text('Média')),
              DataColumn(label: Text('Status')),
            ],
            rows: alunos.map((a) {
              final media = a['media'] as double;
              final status = a['status'] as String;

              return DataRow(cells: [
                DataCell(Text(a['id'] ?? '-')),
                DataCell(Text(a['nome'] ?? '-')),
                DataCell(Text(
                  media.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _corStatus(status).withOpacity(.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _corStatus(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  // ============================================================  
  // 🔹 Carregar notas de todos os alunos  
  // ============================================================
  Future<List<Map<String, dynamic>>> _carregarNotasAlunos() async {
    final List<Map<String, dynamic>> resultado = [];
    final db = FirebaseFirestore.instance;

    await Future.wait(_alunos.map((aluno) async {
      final ra = aluno['ra'] ?? aluno['id'];

      final snap = await db
          .collection('notas')
          .where('alunoRA', isEqualTo: ra)
          .get();

      final notas = snap.docs.map((d) => d.data()).toList();

      final media = _mediaGeralAluno(notas);
      final status = _status(media);

      resultado.add({
        'id': ra,
        'nome': aluno['nome'] ?? '-',
        'media': media,
        'status': status,
      });
    }));

    return resultado;
  }
}
