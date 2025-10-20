import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Tela para lançamento de notas e boletim consolidado.
/// - Turmas do professor logado
/// - Alunos da turma selecionada
/// - Atividades (com filtro por disciplina)
/// - Persistência em /notas (docId = `${atividadeId}_${alunoUid}`)
class TabelaNotasPage extends StatefulWidget {
  const TabelaNotasPage({super.key});

  @override
  State<TabelaNotasPage> createState() => _TabelaNotasPageState();
}

class _TabelaNotasPageState extends State<TabelaNotasPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;

  String? _turmaSelecionada;
  String? _disciplinaSelecionada;

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];
  List<Map<String, dynamic>> _atividades = [];

  /// Mapa: alunoUid -> { atividadeId: nota }
  final Map<String, Map<String, double>> _notas = {};
  /// Cache: turmaId -> média
  final Map<String, double> _mediaTurmaCache = {};

  late TabController _tab;
  bool _carregando = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _carregarTurmas();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // -----------------------------
  // Carga de dados
  // -----------------------------
  Future<void> _carregarTurmas() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final qs = await FirebaseFirestore.instance
          .collection('turmas')
          .where('professorId', isEqualTo: uid)
          .get();

      setState(() {
        _turmas = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (_turmas.isNotEmpty) {
          _turmaSelecionada ??= _turmas.first['id'] as String;
          _carregarAlunosAtividadesENotas();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar turmas: $e')),
      );
    }
  }

  Future<void> _carregarAlunosAtividadesENotas() async {
    final turmaId = _turmaSelecionada;
    if (turmaId == null) return;

    setState(() => _carregando = true);
    try {
      // alunos
      final alunosSnap = await FirebaseFirestore.instance
          .collection('alunos')
          .where('turmaId', isEqualTo: turmaId)
          .orderBy('nome')
          .get();
      _alunos = alunosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // atividades (todas da(s) turma(s) selecionada(s))
      final atividadesSnap = await FirebaseFirestore.instance
          .collection('atividades')
          .where('turmaIds', arrayContains: turmaId)
          .orderBy('prazo')
          .get();
      _atividades =
          atividadesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // notas existentes
      final notasSnap = await FirebaseFirestore.instance
          .collection('notas')
          .where('turmaId', isEqualTo: turmaId)
          .get();

      _notas.clear();
      for (final d in notasSnap.docs) {
        final data = d.data();
        final alunoUid = (data['alunoUid'] ?? '').toString();
        final atividadeId = (data['atividadeId'] ?? '').toString();
        final nota = (data['nota'] ?? 0).toDouble();
        if (alunoUid.isEmpty || atividadeId.isEmpty) continue;

        _notas.putIfAbsent(alunoUid, () => {});
        _notas[alunoUid]![atividadeId] = nota;
      }

      // cache média
      _mediaTurmaCache[turmaId] = _calcularMediaTurma();

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // -----------------------------
  // Cálculos
  // -----------------------------
  List<Map<String, dynamic>> _atividadesFiltradas() {
    if (_disciplinaSelecionada == null || _disciplinaSelecionada!.isEmpty) {
      return _atividades;
    }
    return _atividades
        .where((a) =>
            (a['disciplina'] ?? '').toString() == _disciplinaSelecionada)
        .toList();
  }

  double _mediaAluno(String alunoId) {
    final atividades = _atividadesFiltradas();
    if (atividades.isEmpty) return 0;

    double soma = 0, somaPesos = 0;
    for (final atv in atividades) {
      final peso = (atv['peso'] ?? 1).toDouble();
      final atvId = (atv['id']).toString();
      final n = _notas[alunoId]?[atvId] ?? 0.0;
      soma += n * peso;
      somaPesos += peso;
    }
    return somaPesos == 0 ? 0 : soma / somaPesos;
  }

  double _calcularMediaTurma() {
    final atividades = _atividadesFiltradas();
    if (_alunos.isEmpty || atividades.isEmpty) return 0;

    double soma = 0;
    for (final a in _alunos) {
      soma += _mediaAluno(a['id']);
    }
    return soma / _alunos.length;
  }

  // -----------------------------
  // Persistência
  // -----------------------------
  Future<void> _salvarNotas() async {
    final turmaId = _turmaSelecionada;
    if (turmaId == null) return;

    setState(() => _salvando = true);
    try {
      final uid = _auth.currentUser?.uid;

      final batch = FirebaseFirestore.instance.batch();
      final notasRef = FirebaseFirestore.instance.collection('notas');

      for (final alunoEntry in _notas.entries) {
        final alunoUid = alunoEntry.key;

        final alunoInfo =
            _alunos.firstWhere((e) => e['id'] == alunoUid, orElse: () => {});
        final alunoRA = (alunoInfo['ra'] ?? '').toString();

        for (final atvEntry in alunoEntry.value.entries) {
          final atividadeId = atvEntry.key;
          final nota = atvEntry.value;

          final atv = _atividades.firstWhere(
            (a) => a['id'] == atividadeId,
            orElse: () => {},
          );
          final disciplina = (atv['disciplina'] ?? '').toString();
          final titulo = (atv['titulo'] ?? '').toString();

          final docId = '${atividadeId}_$alunoUid';
          final docRef = notasRef.doc(docId);

          batch.set(
            docRef,
            {
              'atividadeId': atividadeId,
              'atividadeTitulo': titulo,
              'disciplina': disciplina,
              'alunoUid': alunoUid,
              'alunoRA': alunoRA,
              'turmaId': turmaId,
              'professorId': uid,
              'nota': nota,
              'dataLancamento': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }

      await batch.commit();

      // Atualiza média no doc do aluno
      final alunosCol = FirebaseFirestore.instance.collection('alunos');
      for (final aluno in _alunos) {
        final media = _mediaAluno(aluno['id']);
        await alunosCol
            .doc(aluno['id'])
            .set({'media': media}, SetOptions(merge: true));
      }

      // recache
      _mediaTurmaCache[turmaId] = _calcularMediaTurma();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notas salvas e médias atualizadas!')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // -----------------------------
  // UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Scaffold(
      backgroundColor: th.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Tabela de Notas'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _filtros(),
                const SizedBox(height: 6),
                TabBar(
                  controller: _tab,
                  indicatorColor: Colors.orange,
                  labelColor: Colors.black,
                  tabs: const [
                    Tab(text: 'Lançamento de Notas'),
                    Tab(text: 'Boletim Consolidado'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _tabelaLancamento(),
                      _boletimConsolidado(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          // turma
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _turmaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Turma',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _turmas
                  .map((t) => DropdownMenuItem<String>(
                        value: t['id'],
                        child: Text((t['nome'] ?? 'Turma').toString()),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _turmaSelecionada = v;
                  _disciplinaSelecionada = null;
                });
                await _carregarAlunosAtividadesENotas();
              },
            ),
          ),
          const SizedBox(width: 10),
          // disciplina
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _disciplinaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Disciplina',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _atividades
                  .map((a) => (a['disciplina'] ?? '').toString())
                  .where((d) => d.trim().isNotEmpty)
                  .toSet()
                  .map((d) => DropdownMenuItem<String>(
                        value: d,
                        child: Text(d),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _disciplinaSelecionada = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabelaLancamento() {
    final atividades = _atividadesFiltradas();
    if (_alunos.isEmpty || atividades.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Selecione uma turma e verifique se há atividades cadastradas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Aluno')),
                ...atividades.map(
                  (a) => DataColumn(
                    label: Text(
                      (a['titulo'] ?? '-').toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              rows: _alunos.map((aluno) {
                final alunoId = aluno['id'] as String;
                return DataRow(
                  cells: [
                    DataCell(Text((aluno['nome'] ?? '-').toString())),
                    ...atividades.map((a) {
                      final atvId = a['id'] as String;
                      final valor = _notas[alunoId]?[atvId] ?? 0.0;
                      final ctrl = TextEditingController(
                        text: NumberFormat.decimalPattern('pt_BR')
                            .format(valor)
                            .replaceAll('.', ','), // apenas visual
                      );

                      return DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90),
                          child: TextFormField(
                            controller: ctrl,
                            textAlign: TextAlign.center,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true, signed: false),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (v) {
                              final parse = double.tryParse(
                                      v.trim().replaceAll(',', '.')) ??
                                  0.0;
                              setState(() {
                                _notas.putIfAbsent(alunoId, () => {});
                                _notas[alunoId]![atvId] = parse;
                              });
                            },
                            onFieldSubmitted: (_) => _salvarNotas(),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3b6cff),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: _salvando ? null : _salvarNotas,
            icon: _salvando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Salvar notas'),
          ),
        ),
      ],
    );
  }

  Widget _boletimConsolidado() {
    final atividades = _atividadesFiltradas();
    if (_alunos.isEmpty || atividades.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child:
              Text('Sem dados suficientes para o boletim desta seleção.'),
        ),
      );
    }

    final mediaTurma =
        _mediaTurmaCache[_turmaSelecionada] ?? _calcularMediaTurma();

    final columns = <DataColumn>[
      const DataColumn(label: Text('Aluno')),
      ...atividades.map((a) => DataColumn(
            label: Text((a['titulo'] ?? '-').toString()),
          )),
      const DataColumn(label: Text('Média')),
      const DataColumn(label: Text('Desempenho')),
    ];

    final rows = _alunos.map((aluno) {
      final alunoId = aluno['id'] as String;
      final mediaAluno = _mediaAluno(alunoId);
      final diff = mediaAluno - mediaTurma;

      final desempenho = diff >= 0.5
          ? 'Acima da média'
          : diff <= -0.5
              ? 'Abaixo da média'
              : 'Dentro da média';

      return DataRow(
        cells: [
          DataCell(Text((aluno['nome'] ?? '-').toString())),
          ...atividades.map((a) {
            final n = _notas[alunoId]?[a['id']] ?? 0.0;
            return DataCell(Text(n.toStringAsFixed(1)));
          }),
          DataCell(Text(mediaAluno.toStringAsFixed(2))),
          DataCell(Text(desempenho)),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Text(
            'Média da turma: ${mediaTurma.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: columns, rows: rows),
          ),
        ),
      ],
    );
  }
}
