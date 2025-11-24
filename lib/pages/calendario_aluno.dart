// -------------------------------------------------------------
//   CALENDÁRIO DO ALUNO — VERSÃO FINAL + EVENTOS AO CLICAR
// -------------------------------------------------------------

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'atividade_detalhe.dart';

class CalendarioAlunoPage extends StatefulWidget {
  const CalendarioAlunoPage({super.key});

  @override
  State<CalendarioAlunoPage> createState() => _CalendarioAlunoPageState();
}

class _CalendarioAlunoPageState extends State<CalendarioAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();

  bool _loading = true;
  String? _erro;

  final Map<String, List<_CalEvent>> _byDay = {};
  final _fmtDayKey = DateFormat('yyyy-MM-dd');

  int _qProvas = 0;
  int _qEntregas = 0;
  int _qApres = 0;
  int _qRecup = 0;

  List<_CalEvent> _proximos = [];
  String? _alunoRa;

  // 🔥 NOVO → armazenar eventos do dia selecionado
  List<_CalEvent> _eventosSelecionados = [];

  // 🔥 NOVO → armazenar filtro de resumo do mês
  String? _filtroResumo;

  @override
  void initState() {
    super.initState();
    _carregarMes(_visibleMonth);
  }

  void _mesAnterior() {
    final anterior = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    final limiteDia = DateTime(anterior.year, anterior.month + 1, 0).day;
    setState(() {
      _visibleMonth = anterior;
      final diaAjustado = _selected.day.clamp(1, limiteDia);
      _selected = DateTime(anterior.year, anterior.month, diaAjustado);
    });
    _carregarMes(_visibleMonth);
  }

  void _mesSeguinte() {
    final proximo = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    final limiteDia = DateTime(proximo.year, proximo.month + 1, 0).day;
    setState(() {
      _visibleMonth = proximo;
      final diaAjustado = _selected.day.clamp(1, limiteDia);
      _selected = DateTime(proximo.year, proximo.month, diaAjustado);
    });
    _carregarMes(_visibleMonth);
  }

  DateTime? _parseDataTexto(String texto) {
    try {
      texto = texto.toLowerCase().replaceAll("de ", "");
      final meses = {
        "janeiro": 1, "fevereiro": 2, "março": 3, "abril": 4, "maio": 5,
        "junho": 6, "julho": 7, "agosto": 8, "setembro": 9, "outubro": 10,
        "novembro": 11, "dezembro": 12
      };

      final partes = texto.split(" ");
      if (partes.length < 3) return null;

      final dia = int.tryParse(partes[0]);
      final mes = meses[partes[1]];
      final ano = int.tryParse(partes[2]);

      if (dia != null && mes != null && ano != null) {
        return DateTime(ano, mes, dia);
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // 🔵 Carregar atividades do mês
  // ============================================================
  Future<void> _carregarMes(DateTime month) async {
    setState(() {
      _loading = true;
      _erro = null;
      _byDay.clear();

      _qProvas = _qEntregas = _qApres = _qRecup = 0;
      _eventosSelecionados = [];
      _filtroResumo = null;
      _proximos = [];
    });

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception("Usuário não autenticado");

      final userSnap = await _db.collection('users').doc(uid).get();
      final dataUser = userSnap.data() ?? {};
      _alunoRa = dataUser['ra']?.toString();
      final turmas = List<String>.from(dataUser['turmas'] ?? []);

      if (turmas.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final ini = DateTime(month.year, month.month, 1);
      final fim = DateTime(month.year, month.month + 1, 0, 23, 59);

      final List<_CalEvent> eventos = [];

      for (int i = 0; i < turmas.length; i += 10) {
        final fatia = turmas.sublist(i, min(i + 10, turmas.length));

        final atvSnap = await _db
            .collection('atividades')
            .where('turmaId', whereIn: fatia)
            .get();

        for (final doc in atvSnap.docs) {
          final data = doc.data();

          DateTime? dt;
          final bruto = data['data'] ?? data['prazo'] ?? data['criadoEm'];

          if (bruto is Timestamp) {
            dt = bruto.toDate();
          } else if (bruto is String) {
            dt = DateTime.tryParse(bruto) ?? _parseDataTexto(bruto);
          }

          if (dt == null) continue;
          if (dt.isBefore(ini) || dt.isAfter(fim)) continue;

          String tipo = (data['tipo'] ?? "").toString().toLowerCase().trim();
          final tituloLower = (data['titulo'] ?? "").toString().toLowerCase();

          if (tipo.isEmpty) {
            if (tituloLower.contains("prova")) {
              tipo = "prova";
            } else if (tituloLower.contains("apresent") ||
                tituloLower.contains("slide")) {
              tipo = "apresentacao";
            } else if (tituloLower.contains("recup")) {
              tipo = "recuperacao";
            } else {
              tipo = "entrega";
            }
          }

          String disciplinaNome = '';
          if (data['disciplinaNome'] != null) {
            disciplinaNome = data['disciplinaNome'];
          } else if (data['disciplinaId'] != null) {
            disciplinaNome = data['disciplinaId'];
          }

          final atividadeCompleta = {
            "id": doc.id,
            ...data,
          };

          final ev = _CalEvent(
            id: doc.id,
            titulo: data['titulo'] ?? "Atividade",
            descricao: data['descricao'] ?? "",
            turmaId: data['turmaId'],
            tipo: tipo,
            data: dt,
            disciplina: disciplinaNome,
            atividade: atividadeCompleta,
          );

          eventos.add(ev);

          final key = _fmtDayKey.format(DateTime(dt.year, dt.month, dt.day));
          _byDay.putIfAbsent(key, () => []).add(ev);

          switch (tipo) {
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
      }

      final hoje = DateTime.now();
      final hojeLimpo = DateTime(hoje.year, hoje.month, hoje.day);

      _proximos = eventos
          .where((e) => !e.data.isBefore(hojeLimpo))
          .toList()
        ..sort((a, b) => a.data.compareTo(b.data));

      // 🔥 SELECIONA EVENTOS DO DIA ATUAL, AUTOMATICAMENTE
      final keyHoje = _fmtDayKey.format(_selected);
      _eventosSelecionados = _byDay[keyHoje] ?? [];

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _erro = "Erro ao carregar calendário: $e";
        _loading = false;
      });
    }
  }

  // ============================================================
  // 🟦 UI
  // ============================================================
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
                    children: [
                      _header(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _calendarBox(),
                            ),
                            const SizedBox(height: 12),
                            _eventosDoDia(),
                            const SizedBox(height: 12),
                            _secaoProximos(),
                          ],
                        ),
                      ),
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
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Calendário", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              SizedBox(height: 2),
              Text("Provas, entregas e eventos",
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          )
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
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: _mesAnterior),
              Expanded(
                child: Center(
                  child: Text(
                    _headerPtBR(_visibleMonth),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: _mesSeguinte),
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
    const dias = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dias
          .map((d) => SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = first.weekday % 7;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final children = <Widget>[];
    int day = 1;

    for (int r = 0; r < rows; r++) {
      final row = <Widget>[];

      for (int c = 0; c < 7; c++) {
        final index = r * 7 + c;

        if (index < firstWeekday || day > daysInMonth) {
          row.add(const SizedBox(width: 36, height: 36));
        } else {
          final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
          final key = _fmtDayKey.format(date);
          final hasEvent = _byDay[key]?.isNotEmpty ?? false;
          final isSelected = _isSameDay(date, _selected);

          row.add(_dayCell(
            date: date,
            hasEvent: hasEvent,
            selected: isSelected,
            onTap: () {
              setState(() {
                _selected = date;
                _filtroResumo = null;
                _eventosSelecionados = _byDay[key] ?? [];
              });
            },
          ));

          day++;
        }
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row,
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
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: selected ? Colors.white : const Color(0xff2675ff),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔥 EVENTOS DO DIA SELECIONADO
  // ============================================================
  Widget _eventosDoDia() {
    if (_eventosSelecionados.isEmpty && _filtroResumo == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const Text(
          "Nenhum evento nesta data",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    List<_CalEvent> exibir = _eventosSelecionados;

    if (_filtroResumo != null) {
      exibir = _proximos.where((e) => e.tipo == _filtroResumo).toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text("Eventos do Dia",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...exibir.map(_cardEvento)
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 PRÓXIMOS EVENTOS + QUADRO RESUMO (clicável!)
  // ============================================================
  Widget _secaoProximos() {
    return Container(
      color: const Color(0xfff7f7fb),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Próximos Eventos",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _resumoMes(),
          const SizedBox(height: 12),
          if (_proximos.isEmpty)
            const Text(
              "Nenhum evento futuro.",
              style: TextStyle(color: Colors.black54),
            )
          else
            ..._proximos.map(_cardEvento),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 RESUMO DO MÊS (agora com clique!)
  // ============================================================
  Widget _resumoMes() {
    Widget box(String label, int q, Color color, String filtro) {
      return Expanded(
        child: InkWell(
          onTap: () {
            setState(() {
              _filtroResumo = filtro;
              _eventosSelecionados = [];
            });
          },
          child: Column(
            children: [
              Text(
                '$q',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
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
        children: [
          const Text("Resumo do mês",
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              box("Provas", _qProvas, const Color(0xffe53935), "prova"),
              box("Entregas", _qEntregas, const Color(0xffff9800), "entrega"),
              box("Apresentações", _qApres, const Color(0xff1e88e5), "apresentacao"),
              box("Recuperações", _qRecup, const Color(0xff8e24aa), "recuperacao"),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🔥 CARD DE UM EVENTO (agora com navegação!)
  // ============================================================
  Widget _cardEvento(_CalEvent e) {
    final fmt = DateFormat("dd/MM/yyyy HH:mm");
    final cor = _tipoColor(e.tipo);

    return InkWell(
      onTap: () => _abrirAtividade(e),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe6e6ee)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cor.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
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
                      Text(
                        e.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      _chip(_labelTipo(e.tipo),
                          bg: cor.withOpacity(.12), fg: cor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(e.data),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (e.disciplina.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _chip(e.disciplina),
                  ],
                  if (e.descricao.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(e.descricao),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _abrirAtividade(_CalEvent evento) async {
    try {
      final ra = _alunoRa;
      if (ra == null || ra.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("RA do aluno n�o encontrado.")),
        );
        return;
      }

      final atividade = Map<String, dynamic>.from(evento.atividade)
        ..putIfAbsent("id", () => evento.id);
      Map<String, dynamic>? entrega;

      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final entSnap = await _db
            .collection('entregas')
            .where('alunoUid', isEqualTo: uid)
            .where('atividadeId', isEqualTo: evento.id)
            .limit(1)
            .get();
        if (entSnap.docs.isNotEmpty) {
          entrega = {'id': entSnap.docs.first.id, ...entSnap.docs.first.data()};
        }
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AtividadeDetalhePage(
            atividade: atividade,
            entrega: entrega,
            ra: ra,
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro ao abrir atividade: $err")));
    }
  }
  // ============================================================
  // 🔧 Utilidades
  // ============================================================
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
        return const Color(0xff455a64);
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

  Widget _chip(String text,
      {Color bg = const Color(0xffedf2ff),
      Color fg = const Color(0xff4a64ff)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _headerPtBR(DateTime m) {
    const meses = [
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
    return '${meses[m.month][0].toUpperCase()}${meses[m.month].substring(1)} ${m.year}';
  }
}

// ============================================================
// 📌 Modelo de Evento
// ============================================================
class _CalEvent {
  final String id;
  final String titulo;
  final String descricao;
  final String turmaId;
  final String tipo;
  final DateTime data;
  final String disciplina;
  final Map<String, dynamic> atividade;

  _CalEvent({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.turmaId,
    required this.tipo,
    required this.data,
    required this.disciplina,
    required this.atividade,
  });
}
