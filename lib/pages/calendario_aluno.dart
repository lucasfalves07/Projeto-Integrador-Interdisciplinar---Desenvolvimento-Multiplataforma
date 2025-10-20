// lib/pages/calendario_aluno.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class CalendarioAlunoPage extends StatefulWidget {
  const CalendarioAlunoPage({super.key});

  @override
  State<CalendarioAlunoPage> createState() => _CalendarioAlunoPageState();
}

class _CalendarioAlunoPageState extends State<CalendarioAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  bool _loading = true;
  String? _erro;

  // eventos do mês visível (chave: yyyymmdd)
  final Map<String, List<_CalEvent>> _byDay = {};
  final _fmtDayKey = DateFormat('yyyy-MM-dd');
  final _fmtHeader = DateFormat('MMMM yyyy', 'en_US'); // vamos traduzir manualmente para pt

  // resumo por tipo
  int _qProvas = 0;
  int _qEntregas = 0;
  int _qApres = 0;
  int _qRecup = 0;

  // lista "próximos eventos"
  List<_CalEvent> _proximos = [];

  @override
  void initState() {
    super.initState();
    _carregarMes(_visibleMonth);
  }

  Future<void> _carregarMes(DateTime month) async {
    setState(() {
      _loading = true;
      _erro = null;
      _byDay.clear();
      _qProvas = _qEntregas = _qApres = _qRecup = 0;
      _proximos = [];
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _erro = 'Usuário não autenticado';
          _loading = false;
        });
        return;
      }

      // turmas do aluno
      final me = await _fs.getUserByUid(uid);
      final turmas = (me?['turmas'] as List?)?.cast<String>() ?? <String>[];
      if (turmas.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // range do mês
      final ini = DateTime(month.year, month.month, 1);
      final fim = DateTime(month.year, month.month + 1, 1).subtract(const Duration(milliseconds: 1));

      final db = FirebaseFirestore.instance;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

      // whereIn aceita até 10 por consulta → fatiar
      for (int i = 0; i < turmas.length; i += 10) {
        final fatia = turmas.sublist(i, min(i + 10, turmas.length));
        final snap = await db
            .collection('eventos')
            .where('turmaId', whereIn: fatia)
            .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(ini))
            .where('data', isLessThanOrEqualTo: Timestamp.fromDate(fim))
            .get();
        docs.addAll(snap.docs);
      }

      final eventos = <_CalEvent>[];
      for (final d in docs) {
        final m = d.data();
        final ts = m['data'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        if (dt == null) continue;

        final ev = _CalEvent(
          id: d.id,
          titulo: (m['titulo'] ?? 'Evento') as String,
          descricao: (m['descricao'] ?? '') as String,
          turmaId: (m['turmaId'] ?? '') as String,
          tipo: ((m['tipo'] ?? '') as String).toLowerCase(),
          data: dt,
          disciplina: (m['disciplina'] ?? '') as String,
        );
        eventos.add(ev);

        // agrupar por dia
        final key = _fmtDayKey.format(DateTime(dt.year, dt.month, dt.day));
        _byDay.putIfAbsent(key, () => []).add(ev);

        // contadores
        switch (ev.tipo) {
          case 'prova':
            _qProvas++;
            break;
          case 'entrega':
            _qEntregas++;
            break;
          case 'apresentacao':
            _qApres++;
            break;
          case 'recuperacao':
            _qRecup++;
            break;
        }
      }

      // próximos (do mês e a partir de hoje)
      final hoje = DateTime.now();
      _proximos = eventos
          .where((e) => !e.data.isBefore(DateTime(hoje.year, hoje.month, hoje.day)))
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar calendário: $e';
        _loading = false;
      });
    }
  }

  void _mesAnterior() {
    final m = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    setState(() => _visibleMonth = m);
    _carregarMes(m);
  }

  void _mesSeguinte() {
    final m = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    setState(() => _visibleMonth = m);
    _carregarMes(m);
  }

  // traduz o header em português
  String _headerPtBR(DateTime m) {
    final nomes = [
      '',
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];
    return '${nomes[m.month][0].toUpperCase()}${nomes[m.month].substring(1)} ${m.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _calendarBox(),
                      ),
                      const SizedBox(height: 12),
                      _secaoProximos(),
                    ],
                  ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Calendário', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              SizedBox(height: 2),
              Text('Provas, entregas e eventos', style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _mesAnterior,
                icon: const Icon(Icons.chevron_left),
                splashRadius: 20,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _headerPtBR(_visibleMonth),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                onPressed: _mesSeguinte,
                icon: const Icon(Icons.chevron_right),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _weekHeader(),
          const SizedBox(height: 6),
          _monthGrid(),
        ],
      ),
    );
  }

  Widget _weekHeader() {
    const dias = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']; // labels curtos como na imagem
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dias
          .map(
            (d) => SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _monthGrid() {
    final firstDayOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // domingo=0
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final children = <Widget>[];
    int day = 1;

    for (int r = 0; r < rows; r++) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < 7; c++) {
        final index = r * 7 + c;
        if (index < firstWeekday || day > daysInMonth) {
          rowChildren.add(const SizedBox(width: 36, height: 36));
        } else {
          final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
          final key = DateFormat('yyyy-MM-dd').format(date);
          final temEvento = _byDay[key]?.isNotEmpty ?? false;
          final selecionado = _selected.year == date.year &&
              _selected.month == date.month &&
              _selected.day == date.day;

          rowChildren.add(_dayCell(
            date: date,
            hasEvent: temEvento,
            selected: selecionado,
            onTap: () => setState(() => _selected = date),
          ));
          day++;
        }
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: rowChildren,
          ),
        ),
      );
    }

    return Column(children: children);
  }

  Widget _dayCell({
    required DateTime date,
    required bool hasEvent,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isToday = _isSameDay(date, DateTime.now());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? const Color(0xffff8a00) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (hasEvent)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xff2675ff),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _secaoProximos() {
    return Expanded(
      child: Container(
        color: const Color(0xfff7f7fb),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            const Text('Próximos Eventos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _resumoMes(),
            const SizedBox(height: 12),
            ..._proximos.map(_cardEvento),
            if (_proximos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Nenhum evento para este mês',
                      style: TextStyle(color: Colors.black54)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _resumoMes() {
    Widget item(String label, int q, Color c) {
      return Expanded(
        child: Column(
          children: [
            Text('$q', style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo do Mês', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              item('Provas', _qProvas, const Color(0xffe53935)),
              item('Entregas', _qEntregas, const Color(0xffff9800)),
              item('Apresentações', _qApres, const Color(0xff1e88e5)),
              item('Recuperações', _qRecup, const Color(0xff8e24aa)),
            ],
          )
        ],
      ),
    );
  }

  Widget _cardEvento(_CalEvent e) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final cor = _tipoColor(e.tipo);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cor.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_tipoIcon(e.tipo), color: cor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    _chip(_labelTipo(e.tipo), bg: cor.withOpacity(.12), fg: cor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(fmt.format(e.data), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (e.disciplina.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _chip(e.disciplina),
                ],
                if (e.descricao.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(e.descricao),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  IconData _tipoIcon(String t) {
    switch (t) {
      case 'prova':
        return Icons.fact_check;
      case 'entrega':
        return Icons.upload_file;
      case 'apresentacao':
        return Icons.mic;
      case 'recuperacao':
        return Icons.refresh;
      default:
        return Icons.event;
    }
  }

  Color _tipoColor(String t) {
    switch (t) {
      case 'prova':
        return const Color(0xffe53935);
      case 'entrega':
        return const Color(0xffff9800);
      case 'apresentacao':
        return const Color(0xff1e88e5);
      case 'recuperacao':
        return const Color(0xff8e24aa);
      default:
        return const Color(0xff546e7a);
    }
  }

  String _labelTipo(String t) {
    switch (t) {
      case 'prova':
        return 'Prova';
      case 'entrega':
        return 'Entrega';
      case 'apresentacao':
        return 'Apresentação';
      case 'recuperacao':
        return 'Recuperação';
      default:
        return 'Evento';
    }
  }

  Widget _chip(String text, {Color bg = const Color(0xffedf2ff), Color fg = const Color(0xff4a64ff)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _CalEvent {
  final String id;
  final String titulo;
  final String descricao;
  final String turmaId;
  final String tipo; // prova|entrega|apresentacao|recuperacao
  final DateTime data;
  final String disciplina;

  _CalEvent({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.turmaId,
    required this.tipo,
    required this.data,
    required this.disciplina,
  });
}
