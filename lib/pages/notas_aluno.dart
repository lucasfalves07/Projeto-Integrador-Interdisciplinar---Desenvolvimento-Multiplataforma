import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class NotasAlunoPage extends StatefulWidget {
  const NotasAlunoPage({super.key});

  @override
  State<NotasAlunoPage> createState() => _NotasAlunoPageState();
}

class _NotasAlunoPageState extends State<NotasAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();
  final _df = DateFormat('dd/MM/yyyy');

  String _filtroDisciplina = 'Todas as disciplinas';
  String? _erro;
  bool _loading = true;

  List<Map<String, dynamic>> _notas = [];
  Map<String, Map<String, dynamic>> _atividadesById = {};
  String alunoUid = '';
  String alunoRA = '';

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _erro = 'Usuário não autenticado.';
        _loading = false;
      });
      return;
    }

    alunoUid = uid;
    try {
      final alunoData = await _fs.getUserByUid(uid);
      alunoRA = alunoData?['ra'] ?? '';
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar dados: $e';
        _loading = false;
      });
    }
  }

  Stream<List<Map<String, dynamic>>> _streamNotas() {
    final firestore = FirebaseFirestore.instance;
    return firestore
        .collection('notas')
        .where('alunoUid', isEqualTo: alunoUid)
        .snapshots()
        .asyncMap((snap) async {
      final notas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // obtém atividades correspondentes
      final atvIds =
          notas.map((e) => e['atividadeId'] as String? ?? '').toSet().toList();
      final Map<String, Map<String, dynamic>> atividades = {};

      for (var i = 0; i < atvIds.length; i += 10) {
        final fatia = atvIds.sublist(i, min(i + 10, atvIds.length));
        if (fatia.isEmpty) continue;

        final snapAtv = await firestore
            .collection('atividades')
            .where(FieldPath.documentId, whereIn: fatia)
            .get();

        for (var d in snapAtv.docs) {
          atividades[d.id] = {'id': d.id, ...d.data()};
        }
      }

      _atividadesById = atividades;
      return notas;
    });
  }

  static double _round1(double v) => (v * 10).round() / 10.0;

  double _mediaGeral(List<Map<String, dynamic>> notas) {
    if (notas.isEmpty) return 0;
    double soma = 0, somaPesos = 0;
    for (final n in _filtrarNotasPorDisciplina(notas, null)) {
      final atv = _atividadesById[n['atividadeId']] ?? {};
      final peso = ((atv['peso'] ?? 1) as num).toDouble();
      soma += ((n['nota'] as num?)?.toDouble() ?? 0) * peso;
      somaPesos += peso;
    }
    if (somaPesos == 0) return 0;
    return _round1(soma / somaPesos);
  }

  List<Map<String, dynamic>> _filtrarNotasPorDisciplina(
      List<Map<String, dynamic>> base, String? disc) {
    final filtradas =
        base.where((n) => _atividadesById.containsKey(n['atividadeId'])).toList();
    if (disc == null || disc == 'Todas as disciplinas') return filtradas;
    return filtradas
        .where((n) =>
            (_atividadesById[n['atividadeId']]?['disciplina'] ?? '') == disc)
        .toList();
  }

  List<String> _disciplinasDisponiveis() {
    final set = <String>{};
    for (final a in _atividadesById.values) {
      final d = (a['disciplina'] ?? '').toString();
      if (d.isNotEmpty) set.add(d);
    }
    return ['Todas as disciplinas', ...set.toList()..sort()];
  }

  double _mediaDisciplina(List<Map<String, dynamic>> notas, String disc) {
    final filtro = _filtrarNotasPorDisciplina(notas, disc);
    if (filtro.isEmpty) return 0;
    double soma = 0, somaPesos = 0;
    for (final n in filtro) {
      final atv = _atividadesById[n['atividadeId']] ?? {};
      final peso = ((atv['peso'] ?? 1) as num).toDouble();
      soma += ((n['nota'] as num?)?.toDouble() ?? 0) * peso;
      somaPesos += peso;
    }
    if (somaPesos == 0) return 0;
    return _round1(soma / somaPesos);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_erro != null) {
      return Scaffold(
        body: Center(
          child: Text(_erro!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamNotas(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Erro: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final notas = snapshot.data ?? [];
        final mediaGeral = _mediaGeral(notas);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _MediaGeralCard(media: mediaGeral),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _filtroDisciplinaWidget(),
                ),
                const SizedBox(height: 8),
                Expanded(child: _listaDisciplinas(notas)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 2),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notas e Boletim',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 2),
                Text('Acompanhe seu desempenho',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ],
        ),
      );

  Widget _filtroDisciplinaWidget() {
    final itens = _disciplinasDisponiveis();
    if (!itens.contains(_filtroDisciplina)) {
      _filtroDisciplina = 'Todas as disciplinas';
    }
    return DropdownButtonFormField<String>(
      value: _filtroDisciplina,
      isExpanded: true,
      items: itens.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _filtroDisciplina = v ?? 'Todas as disciplinas'),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xfff7f7fb),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffe6e6ee)),
        ),
      ),
    );
  }

  Widget _listaDisciplinas(List<Map<String, dynamic>> notas) {
    final todas = _disciplinasDisponiveis()
        .where((e) => e != 'Todas as disciplinas')
        .toList();
    final mostrar = _filtroDisciplina == 'Todas as disciplinas'
        ? todas
        : todas.where((e) => e == _filtroDisciplina).toList();

    if (mostrar.isEmpty) {
      return const Center(
          child: Text('Sem notas disponíveis',
              style: TextStyle(color: Colors.black54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      itemCount: mostrar.length,
      itemBuilder: (context, i) {
        final disc = mostrar[i];
        final media = _mediaDisciplina(notas, disc);
        final filtro = _filtrarNotasPorDisciplina(notas, disc)
          ..sort((a, b) => (_millis(b['dataLancamento']))
              .compareTo(_millis(a['dataLancamento'])));

        return _CardDisciplina(
          disciplina: disc,
          media: media,
          children: [
            for (final n in filtro)
              _LinhaAtividade(
                titulo: (_atividadesById[n['atividadeId']]?['titulo'] ??
                    'Atividade') as String,
                tipo: (_atividadesById[n['atividadeId']]?['tipo'] ?? 'Prova')
                    as String,
                data: _df.format(
                    DateTime.fromMillisecondsSinceEpoch(_millis(n['dataLancamento']))),
                peso: ((_atividadesById[n['atividadeId']]?['peso'] ?? 1) as num)
                    .toInt(),
                nota: ((n['nota'] as num?)?.toDouble() ?? 0),
              ),
          ],
        );
      },
    );
  }

  int _millis(dynamic ts) {
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is int) return ts;
    if (ts is Map && ts['_seconds'] is int) return (ts['_seconds'] as int) * 1000;
    return DateTime.now().millisecondsSinceEpoch;
  }
}

class _MediaGeralCard extends StatelessWidget {
  final double media;
  const _MediaGeralCard({required this.media});

  @override
  Widget build(BuildContext context) {
    final meta = 7.0;
    final perc = (media / 10).clamp(0.0, 1.0);
    final metaPerc = meta / 10;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xfff7fafb), Color(0xfff1f7ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text('Média Geral',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(media.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xfff57c00))),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 10,
                    width: w,
                    decoration: BoxDecoration(
                      color: const Color(0xffe8eef9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Container(
                    height: 10,
                    width: w * perc,
                    decoration: BoxDecoration(
                      color: const Color(0xfff57c00),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Positioned(
                    left: w * metaPerc,
                    child: Container(
                      height: 10,
                      width: 2,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text('Meta: 7.0 para aprovação',
              style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CardDisciplina extends StatelessWidget {
  final String disciplina;
  final double media;
  final List<Widget> children;

  const _CardDisciplina({
    required this.disciplina,
    required this.media,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                    child: Text(disciplina,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700))),
                Text(media.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _LinhaAtividade extends StatelessWidget {
  final String titulo;
  final String tipo;
  final String data;
  final int peso;
  final double nota;

  const _LinhaAtividade({
    required this.titulo,
    required this.tipo,
    required this.data,
    required this.peso,
    required this.nota,
  });

  Color get _notaColor {
    if (nota >= 8) return Colors.green;
    if (nota >= 6) return const Color(0xfff57c00);
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xfffcfbff),
        border: Border(bottom: BorderSide(color: Color(0xffeeeeef))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(data),
                    _chip(tipo),
                    _chip('Peso $peso'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nota.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _notaColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe6e6ee)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      );
}
