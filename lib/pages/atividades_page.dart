import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as x;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AtividadesPage extends StatefulWidget {
  const AtividadesPage({super.key});

  @override
  State<AtividadesPage> createState() => _AtividadesPageState();
}

class _AtividadesPageState extends State<AtividadesPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  String? _turmaSelecionada;
  String? _disciplinaSelecionada;

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];
  List<Map<String, dynamic>> _atividades = [];

  final Map<String, Map<String, double>> _notas = {};
  final Map<String, double> _mediaTurma = {};

  late TabController _tabController;
  bool _carregando = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _carregarTurmas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarTurmas() async {
    try {
      final prof = _auth.currentUser?.uid;
      final snap = await FirebaseFirestore.instance
          .collection('turmas')
          .where('professorId', isEqualTo: prof)
          .get();

      if (!mounted) return;
      setState(() {
        _turmas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao carregar turmas: $e')));
    }
  }

  Future<void> _carregarAlunosEDados() async {
    if (_turmaSelecionada == null) return;
    setState(() => _carregando = true);

    try {
      final alunosSnap = await FirebaseFirestore.instance
          .collection('alunos')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();
      _alunos = alunosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final atividadesSnap = await FirebaseFirestore.instance
          .collection('atividades')
          .where('turmaIds', arrayContains: _turmaSelecionada)
          .get();
      _atividades =
          atividadesSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final notasSnap = await FirebaseFirestore.instance
          .collection('notas')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();

      _notas.clear();
      for (var doc in notasSnap.docs) {
        final n = doc.data();
        final aluno = (n['alunoUid'] ?? '').toString();
        final atv = (n['atividadeId'] ?? '').toString();
        final nota = (n['nota'] ?? 0).toDouble();
        if (aluno.isEmpty || atv.isEmpty) continue;
        _notas.putIfAbsent(aluno, () => {});
        _notas[aluno]![atv] = nota;
      }

      _mediaTurma[_turmaSelecionada!] = _calcularMediaTurma();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  double _mediaAluno(String alunoId) {
    final atividades = _atividadesFiltradas();
    double soma = 0, pesos = 0;
    for (var atv in atividades) {
      final peso = (atv['peso'] ?? 1).toDouble();
      final nota = _notas[alunoId]?[atv['id']] ?? 0;
      soma += nota * peso;
      pesos += peso;
    }
    return pesos == 0 ? 0 : soma / pesos;
  }

  double _calcularMediaTurma() {
    if (_alunos.isEmpty) return 0;
    double soma = 0;
    for (final aluno in _alunos) {
      soma += _mediaAluno(aluno['id']);
    }
    return soma / _alunos.length;
  }

  List<Map<String, dynamic>> _atividadesFiltradas() {
    if (_disciplinaSelecionada == null || _disciplinaSelecionada!.isEmpty) {
      return _atividades;
    }
    return _atividades
        .where((a) =>
            (a['disciplina'] ?? '').toString() == _disciplinaSelecionada)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
        title: const Text(
          'Atividades e Notas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_alunos.isNotEmpty)
            TextButton.icon(
              onPressed: _mostrarDialogoExportar,
              icon: const Icon(Icons.download_rounded, color: Colors.black87),
              label: const Text('Exportar',
                  style: TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffff9800),
              foregroundColor: Colors.white,
            ),
            onPressed: _abrirFormularioNovaAtividade,
            icon: const Icon(Icons.add),
            label: const Text('Nova Atividade'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _filtrosTurmaDisciplina(),
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.orange,
                    labelColor: Colors.black,
                    tabs: const [
                      Tab(text: 'Lançamento de Notas'),
                      Tab(text: 'Boletim Consolidado'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _tabelaLancamento(),
                        _boletimConsolidado(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _filtrosTurmaDisciplina() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
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
                          child: Text(t['nome'] ?? 'Turma'),
                        ))
                    .toList(),
                onChanged: (v) async {
                  setState(() => _turmaSelecionada = v);
                  await _carregarAlunosEDados();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _disciplinaSelecionada,
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _atividades
                    .map((a) => a['disciplina']?.toString())
                    .toSet()
                    .where((e) => e != null && e!.trim().isNotEmpty)
                    .map((d) => DropdownMenuItem<String>(
                          value: d!,
                          child: Text(d),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _disciplinaSelecionada = v),
              ),
            ),
          ],
        ),
      );

  Widget _tabelaLancamento() {
    final atividades = _atividadesFiltradas();
    if (_alunos.isEmpty || atividades.isEmpty) {
      return const Center(
          child: Text('Selecione uma turma e adicione atividades.'));
    }

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Aluno')),
              ...atividades
                  .map((a) => DataColumn(label: Text(a['titulo'] ?? '-')))
                  .toList(),
            ],
            rows: _alunos.map((aluno) {
              final alunoId = aluno['id'];
              return DataRow(cells: [
                DataCell(Text(aluno['nome'] ?? '-')),
                ...atividades.map((a) {
                  final atvId = a['id'];
                  final valor = _notas[alunoId]?[atvId] ?? 0;
                  final controller =
                      TextEditingController(text: valor.toString());
                  return DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: TextFormField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        ),
                        onChanged: (v) {
                          final novo =
                              double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          setState(() {
                            _notas.putIfAbsent(alunoId, () => {});
                            _notas[alunoId]![atvId] = novo;
                          });
                        },
                        onFieldSubmitted: (_) => _salvarNotas(),
                      ),
                    ),
                  );
                }).toList(),
              ]);
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
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: const Text('Salvar notas'),
        ),
      ),
    ]);
  }

  Widget _boletimConsolidado() {
    final atividades = _atividadesFiltradas();
    if (_alunos.isEmpty || atividades.isEmpty) {
      return const Center(child: Text('Sem dados para exibir.'));
    }

    final mediaTurma =
        _mediaTurma[_turmaSelecionada ?? ''] ?? _calcularMediaTurma();

    final columns = <DataColumn>[
      const DataColumn(label: Text('Aluno')),
      ...atividades
          .map((a) => DataColumn(label: Text((a['titulo'] ?? '-').toString()))),
      const DataColumn(label: Text('Média')),
      const DataColumn(label: Text('Desempenho')),
    ];

    final rows = _alunos.map((aluno) {
      final alunoId = aluno['id'];
      final mediaAluno = _mediaAluno(alunoId);
      final diff = mediaAluno - mediaTurma;
      final desempenho = diff >= 0.5
          ? 'Acima da média'
          : diff <= -0.5
              ? 'Abaixo da média'
              : 'Dentro da média';
      return DataRow(cells: [
        DataCell(Text(aluno['nome'] ?? '-')),
        ...atividades.map((a) {
          final n = _notas[alunoId]?[a['id']] ?? 0;
          return DataCell(Text(n.toStringAsFixed(1)));
        }),
        DataCell(Text(mediaAluno.toStringAsFixed(2))),
        DataCell(Text(desempenho)),
      ]);
    }).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Text(
          'Média da turma: ${mediaTurma.toStringAsFixed(2)}',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          scrollDirection: Axis.horizontal,
          child: DataTable(columns: columns, rows: rows),
        ),
      ),
    ]);
  }

  Future<void> _salvarNotas() async {
    if (_turmaSelecionada == null) return;
    setState(() => _salvando = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notasRef = FirebaseFirestore.instance.collection('notas');

      for (final alunoEntry in _notas.entries) {
        final alunoUid = alunoEntry.key;
        final alunoInfo =
            _alunos.firstWhere((a) => a['id'] == alunoUid, orElse: () => {});
        final alunoRA = (alunoInfo['ra'] ?? '').toString();

        for (final atividadeEntry in alunoEntry.value.entries) {
          final atividadeId = atividadeEntry.key;
          final nota = atividadeEntry.value;

          final atv = _atividades.firstWhere(
              (a) => a['id'] == atividadeId,
              orElse: () => {});
          final disciplina = (atv['disciplina'] ?? '').toString();
          final atividadeTitulo = (atv['titulo'] ?? '').toString();

          final docId = '${atividadeId}_$alunoUid';
          final docRef = notasRef.doc(docId);

          batch.set(docRef, {
            'atividadeId': atividadeId,
            'atividadeTitulo': atividadeTitulo,
            'disciplina': disciplina,
            'alunoUid': alunoUid,
            'alunoRA': alunoRA,
            'turmaId': _turmaSelecionada,
            'professorId': _auth.currentUser?.uid,
            'nota': nota,
            'dataLancamento': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();
      _mediaTurma[_turmaSelecionada!] = _calcularMediaTurma();

      final alunosCol = FirebaseFirestore.instance.collection('alunos');
      for (final aluno in _alunos) {
        final media = _mediaAluno(aluno['id']);
        await alunosCol
            .doc(aluno['id'])
            .set({'media': media}, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Notas salvas e médias atualizadas!')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _mostrarDialogoExportar() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 14),
              const Text('Exportar boletim',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                  leading: const Icon(Icons.grid_on_rounded),
                  title: const Text('Excel (.xlsx)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportarExcel();
                  }),
              ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: const Text('PDF (.pdf)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportarPDF();
                  }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportarExcel() async {
    try {
      final excel = x.Excel.createExcel();
      final turmaNome = _turmas
          .firstWhere((t) => t['id'] == _turmaSelecionada)['nome']
          .toString();
      final sheet = excel[turmaNome];
      final atividades = _atividadesFiltradas();
      final mediaTurma =
          _mediaTurma[_turmaSelecionada ?? ''] ?? _calcularMediaTurma();

      // Cabeçalho
      sheet.appendRow([
        x.TextCellValue('RA'),
        x.TextCellValue('Aluno'),
        ...atividades.map((a) => x.TextCellValue(a['titulo'] ?? '-')),
        x.TextCellValue('Média'),
        x.TextCellValue('Desempenho'),
      ]);

      // Linhas
      for (var aluno in _alunos) {
        final alunoId = aluno['id'];
        final mediaAluno = _mediaAluno(alunoId);
        final diff = mediaAluno - mediaTurma;
        final desempenho = diff >= 0.5
            ? 'Acima da média'
            : diff <= -0.5
                ? 'Abaixo da média'
                : 'Dentro da média';
        final notas = atividades.map((a) {
          final n = _notas[alunoId]?[a['id']] ?? 0;
          return x.TextCellValue(n.toStringAsFixed(1));
        }).toList();

        sheet.appendRow([
          x.TextCellValue(aluno['ra'] ?? ''),
          x.TextCellValue(aluno['nome'] ?? ''),
          ...notas,
          x.TextCellValue(mediaAluno.toStringAsFixed(2)),
          x.TextCellValue(desempenho),
        ]);
      }

      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/Boletim_${turmaNome.replaceAll(" ", "_")}.xlsx';
        final bytes = excel.encode();
        if (bytes != null) {
          final file = File(path)..writeAsBytesSync(bytes);
          await Share.shareXFiles([XFile(file.path)],
              text: 'Boletim da turma $turmaNome exportado com sucesso!');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Exportação de Excel não é suportada no navegador.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao exportar Excel: $e')));
    }
  }

  Future<void> _exportarPDF() async {
    try {
      final pdf = pw.Document();
      final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final turmaNome = _turmas
          .firstWhere((t) => t['id'] == _turmaSelecionada)['nome']
          .toString();
      final atividades = _atividadesFiltradas();
      final mediaTurma =
          _mediaTurma[_turmaSelecionada ?? ''] ?? _calcularMediaTurma();

      final headers = [
        'RA',
        'Aluno',
        ...atividades.map((a) => (a['titulo'] ?? '').toString()),
        'Média',
        'Desempenho',
      ];

      final data = _alunos.map((a) {
        final alunoId = a['id'];
        final mediaAluno = _mediaAluno(alunoId);
        final diff = mediaAluno - mediaTurma;
        final desempenho = diff >= 0.5
            ? 'Acima da média'
            : diff <= -0.5
                ? 'Abaixo da média'
                : 'Dentro da média';
        final notas = atividades.map((atv) {
          final n = _notas[alunoId]?[atv['id']] ?? 0;
          return n.toStringAsFixed(1);
        }).toList();
        return [
          (a['ra'] ?? '').toString(),
          (a['nome'] ?? '').toString(),
          ...notas,
          mediaAluno.toStringAsFixed(2),
          desempenho,
        ];
      }).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Boletim da Turma: $turmaNome',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800)),
                pw.Text('Emitido em $date'),
              ],
            ),
          ),
          pw.Table.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.black),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Média Geral da Turma: ${mediaTurma.toStringAsFixed(2)}',
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800),
          ),
        ],
      ));

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar PDF: $e')));
    }
  }

  Future<void> _abrirFormularioNovaAtividade() async {
    final tituloCtrl = TextEditingController();
    final disciplinaCtrl = TextEditingController();
    final pesoCtrl = TextEditingController(text: '1');
    final prazoCtrl = TextEditingController();
    DateTime? prazoSelecionado;
    String? turmaId = _turmaSelecionada;

    await showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      context: context,
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding:
              EdgeInsets.only(bottom: bottom, left: 16, right: 16, top: 14),
          child: StatefulBuilder(builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nova Atividade',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: tituloCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: disciplinaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Disciplina',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: turmaId,
                    decoration: const InputDecoration(
                      labelText: 'Turma',
                      border: OutlineInputBorder(),
                    ),
                    items: _turmas
                        .map((t) => DropdownMenuItem<String>(
                              value: t['id'],
                              child: Text(t['nome'] ?? 'Turma'),
                            ))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => turmaId = v),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pesoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: prazoCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Prazo',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final pick = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                            initialDate: DateTime.now(),
                          );
                          if (pick != null) {
                            setStateDialog(() {
                              prazoSelecionado = pick;
                              prazoCtrl.text =
                                  DateFormat('dd/MM/yyyy').format(pick);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffff9800),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar Atividade'),
                    onPressed: () async {
                      if (tituloCtrl.text.isEmpty ||
                          turmaId == null ||
                          prazoSelecionado == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Preencha todos os campos obrigatórios')));
                        return;
                      }

                      await FirebaseFirestore.instance
                          .collection('atividades')
                          .add({
                        'titulo': tituloCtrl.text.trim(),
                        'disciplina': disciplinaCtrl.text.trim(),
                        'turmaIds': [turmaId],
                        'peso': double.tryParse(pesoCtrl.text) ?? 1,
                        'prazo': Timestamp.fromDate(prazoSelecionado!),
                        'professorId': _auth.currentUser?.uid,
                        'criadoEm': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content:
                                Text('Atividade criada com sucesso!')));
                        if (_turmaSelecionada == turmaId) {
                          await _carregarAlunosEDados();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
