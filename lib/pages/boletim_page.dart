// lib/pages/boletim_page.dart
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

class BoletimPage extends StatefulWidget {
  const BoletimPage({super.key});

  @override
  State<BoletimPage> createState() => _BoletimPageState();
}

class _BoletimPageState extends State<BoletimPage> {
  final _auth = FirebaseAuth.instance;

  String? _turmaSelecionada;
  String? _disciplinaSelecionada;

  bool _carregando = false;

  // Dados
  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];
  List<Map<String, dynamic>> _atividades = [];
  final Map<String, Map<String, double>> _notas = {}; // alunoId -> {atividadeId: nota}
  double _mediaTurma = 0;

  // Ordenação
  String _ordem = 'nome_asc'; // nome_asc | media_desc | media_asc

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar turmas: $e')),
      );
    }
  }

  Future<void> _carregarTudo() async {
    if (_turmaSelecionada == null) return;
    setState(() => _carregando = true);

    try {
      // Alunos da turma
      final alunosSnap = await FirebaseFirestore.instance
          .collection('alunos')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();
      _alunos = alunosSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Atividades — tenta 'turmaIds' (array) e, se vier vazio, tenta 'turmaId' (string)
      _atividades = [];
      final atvTry1 = await FirebaseFirestore.instance
          .collection('atividades')
          .where('turmaIds', arrayContains: _turmaSelecionada)
          .get();

      if (atvTry1.docs.isNotEmpty) {
        _atividades = atvTry1.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } else {
        final atvTry2 = await FirebaseFirestore.instance
            .collection('atividades')
            .where('turmaId', isEqualTo: _turmaSelecionada)
            .get();
        _atividades = atvTry2.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }

      // Notas da turma
      final notasSnap = await FirebaseFirestore.instance
          .collection('notas')
          .where('turmaId', isEqualTo: _turmaSelecionada)
          .get();

      _notas.clear();
      for (final doc in notasSnap.docs) {
        final n = doc.data();
        final aluno = (n['alunoUid'] ?? '').toString();
        final atv = (n['atividadeId'] ?? '').toString();
        final nota = (n['nota'] ?? 0).toDouble();
        if (aluno.isEmpty || atv.isEmpty) continue;
        _notas.putIfAbsent(aluno, () => {});
        _notas[aluno]![atv] = nota;
      }

      // Calcula média da turma
      _mediaTurma = _calcularMediaTurma();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> _atividadesFiltradas() {
    if (_disciplinaSelecionada == null || _disciplinaSelecionada!.isEmpty) {
      return List<Map<String, dynamic>>.from(_atividades);
    }
    return _atividades
        .where((a) => (a['disciplina'] ?? '').toString() == _disciplinaSelecionada)
        .toList();
  }

  double _mediaAluno(String alunoId) {
    final atividades = _atividadesFiltradas();
    if (atividades.isEmpty) return 0;

    double soma = 0, pesos = 0;
    for (final atv in atividades) {
      final peso = (atv['peso'] ?? 1).toDouble();
      final nota = _notas[alunoId]?[atv['id']] ?? 0;
      soma += nota * peso;
      pesos += peso;
    }
    return pesos == 0 ? 0 : (soma / pesos);
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

  String _statusAluno(double media) {
    if (media >= 6.0) return 'Aprovado';
    if (media >= 4.0) return 'Recuperação';
    return 'Reprovado';
    // Se você preferir status relativo à média da turma, troque a regra acima.
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final atividades = _atividadesFiltradas();

    // Monta alunos + métricas para a tabela
    final linhas = _alunos.map((aluno) {
      final alunoId = aluno['id'];
      final media = _mediaAluno(alunoId);
      final status = _statusAluno(media);
      return {
        'aluno': aluno,
        'media': media,
        'status': status,
      };
    }).toList();

    // Ordenação
    linhas.sort((a, b) {
      switch (_ordem) {
        case 'media_desc':
          return (b['media'] as double).compareTo(a['media'] as double);
        case 'media_asc':
          return (a['media'] as double).compareTo(b['media'] as double);
        case 'nome_asc':
        default:
          final an = (a['aluno']['nome'] ?? '').toString().toLowerCase();
          final bn = (b['aluno']['nome'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boletim da Turma'),
        actions: [
          IconButton(
            tooltip: 'Exportar PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: (_alunos.isEmpty || atividades.isEmpty) ? null : _exportarPDF,
          ),
          IconButton(
            tooltip: 'Exportar Excel',
            icon: const Icon(Icons.grid_on_rounded),
            onPressed: (_alunos.isEmpty || atividades.isEmpty) ? null : _exportarExcel,
          ),
          PopupMenuButton<String>(
            tooltip: 'Ordenar',
            onSelected: (v) => setState(() => _ordem = v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'nome_asc', child: Text('Ordenar por Nome (A→Z)')),
              PopupMenuItem(value: 'media_desc', child: Text('Ordenar por Média (maior→menor)')),
              PopupMenuItem(value: 'media_asc', child: Text('Ordenar por Média (menor→maior)')),
            ],
            icon: const Icon(Icons.sort),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _filtros(atividades),
                const SizedBox(height: 6),
                if (_turmaSelecionada != null && _alunos.isNotEmpty && atividades.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Média da turma: ${_mediaTurma.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Expanded(
                  child: _tabela(linhas, atividades),
                ),
              ],
            ),
    );
  }

  Widget _filtros(List<Map<String, dynamic>> atividadesFiltradasAgora) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _turmaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Turma',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _turmas
                  .map((t) => DropdownMenuItem<String>(
                        value: t['id'],
                        child: Text(t['nome'] ?? 'Turma'),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  _turmaSelecionada = v;
                  _disciplinaSelecionada = null;
                });
                await _carregarTudo();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _disciplinaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Disciplina',
                isDense: true,
                border: OutlineInputBorder(),
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
              onChanged: (v) {
                setState(() => _disciplinaSelecionada = v);
                // Recalcula média da turma quando filtramos por disciplina
                setState(() => _mediaTurma = _calcularMediaTurma());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabela(List<Map<String, dynamic>> linhas, List<Map<String, dynamic>> atividades) {
    if (_turmaSelecionada == null) {
      return const Center(child: Text('Selecione uma turma.'));
    }
    if (_alunos.isEmpty) {
      return const Center(child: Text('Nenhum aluno nesta turma.'));
    }
    if (atividades.isEmpty) {
      return const Center(child: Text('Não há atividades cadastradas.'));
    }

    final columns = <DataColumn>[
      const DataColumn(label: Text('Aluno')),
      ...atividades.map((a) => DataColumn(label: Text((a['titulo'] ?? '-').toString()))),
      const DataColumn(label: Text('Média')),
      const DataColumn(label: Text('Status')),
    ];

    final dataRows = linhas.map((linha) {
      final aluno = linha['aluno'] as Map<String, dynamic>;
      final alunoId = aluno['id'];
      final media = (linha['media'] as double);
      final status = (linha['status'] as String);

      final cellsNotas = atividades.map((a) {
        final n = _notas[alunoId]?[a['id']] ?? 0;
        return DataCell(Text(n.toStringAsFixed(1)));
      });

      return DataRow(
        cells: [
          DataCell(Text((aluno['nome'] ?? '-').toString())),
          ...cellsNotas,
          DataCell(Text(media.toStringAsFixed(2))),
          DataCell(_statusChip(status)),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      scrollDirection: Axis.horizontal,
      child: DataTable(columns: columns, rows: dataRows),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    switch (status) {
      case 'Aprovado':
        bg = Colors.green.shade600;
        break;
      case 'Recuperação':
        bg = Colors.orange.shade700;
        break;
      default:
        bg = Colors.red.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------- EXPORTAÇÕES ----------
  Future<void> _exportarPDF() async {
    try {
      final atividades = _atividadesFiltradas();
      final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
      final turmaNome = (_turmas.firstWhere(
        (t) => t['id'] == _turmaSelecionada,
        orElse: () => {'nome': 'Turma'},
      )['nome'] ??
          'Turma')
          .toString();

      final headers = [
        'RA',
        'Aluno',
        ...atividades.map((a) => (a['titulo'] ?? '').toString()),
        'Média',
        'Status',
      ];

      final data = _alunos.map((a) {
        final alunoId = a['id'];
        final media = _mediaAluno(alunoId);
        final status = _statusAluno(media);
        final notas = atividades.map((atv) {
          final n = _notas[alunoId]?[atv['id']] ?? 0;
          return n.toStringAsFixed(1);
        }).toList();
        return [
          (a['ra'] ?? '').toString(),
          (a['nome'] ?? '').toString(),
          ...notas,
          media.toStringAsFixed(2),
          status,
        ];
      }).toList();

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Boletim - $turmaNome',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      )),
                  pw.Text('Emitido em $date'),
                ],
              ),
            ),
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.black),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Média Geral da Turma: ${_mediaTurma.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar PDF: $e')),
      );
    }
  }

  // Helper para Excel 4.x: usar tipos corretos (TextCellValue / DoubleCellValue)
  x.TextCellValue _txt(String v) => x.TextCellValue(v);
  x.DoubleCellValue _numD(double v) => x.DoubleCellValue(v);

  Future<void> _exportarExcel() async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exportação Excel não é suportada no navegador. Use PDF.'),
          ),
        );
        return;
      }

      final atividades = _atividadesFiltradas();
      final turmaNome = (_turmas.firstWhere(
        (t) => t['id'] == _turmaSelecionada,
        orElse: () => {'nome': 'Turma'},
      )['nome'] ??
          'Turma')
          .toString();

      final excel = x.Excel.createExcel();
      final sheet = excel[turmaNome];

      // Cabeçalho
      sheet.appendRow([
        _txt('RA'),
        _txt('Aluno'),
        ...atividades.map((a) => _txt((a['titulo'] ?? '-').toString())),
        _txt('Média'),
        _txt('Status'),
      ]);

      // Linhas
      for (final a in _alunos) {
        final alunoId = a['id'];
        final media = _mediaAluno(alunoId);
        final status = _statusAluno(media);

        final notasCells = atividades.map((atv) {
          final n = _notas[alunoId]?[atv['id']] ?? 0.0;
          return _numD(double.parse(n.toStringAsFixed(1)));
        });

        sheet.appendRow([
          _txt((a['ra'] ?? '').toString()),
          _txt((a['nome'] ?? '').toString()),
          ...notasCells,
          _numD(double.parse(media.toStringAsFixed(2))),
          _txt(status),
        ]);
      }

      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/Boletim_${turmaNome.replaceAll(' ', '_')}.xlsx';
      final bytes = excel.encode();
      if (bytes != null) {
        final file = File(filePath)..writeAsBytesSync(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Boletim da turma $turmaNome',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar Excel: $e')),
      );
    }
  }
}
