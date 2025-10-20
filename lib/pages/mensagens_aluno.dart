// lib/pages/mensagens_aluno.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class MensagensAlunoPage extends StatefulWidget {
  const MensagensAlunoPage({super.key});

  @override
  State<MensagensAlunoPage> createState() => _MensagensAlunoPageState();
}

class _MensagensAlunoPageState extends State<MensagensAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();
  final _date = DateFormat('dd/MM/yyyy HH:mm');

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _respostaCtrl = TextEditingController();

  bool _loading = true;
  String? _erro;
  List<Map<String, dynamic>> _mensagens = [];

  final Map<String, String> _nomePorUid = {};
  String _filtroDisciplina = 'Todas';

  String alunoRA = '';
  List<String> turmas = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _respostaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _erro = 'Usuário não autenticado';
        _loading = false;
      });
      return;
    }

    try {
      final alunoData = await _fs.getUserByUid(uid);
      alunoRA = alunoData?['ra'] ?? '';
      turmas = (alunoData?['turmas'] as List?)?.cast<String>() ?? <String>[];

      if (turmas.isEmpty && alunoRA.isEmpty) {
        setState(() {
          _mensagens = [];
          _loading = false;
        });
        return;
      }

      final db = FirebaseFirestore.instance;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

      // Lote de busca por turmaId (10 por vez)
      for (int i = 0; i < turmas.length; i += 10) {
        final slice = turmas.sublist(i, min(i + 10, turmas.length));
        final snap = await db
            .collection('mensagens')
            .where('destinatario', whereIn: [...slice, alunoRA])
            .orderBy('enviadaEm', descending: true)
            .get();
        docs.addAll(snap.docs);
      }

      final List<Map<String, dynamic>> msgs = [];
      final autores = <String>{};

      for (final d in docs) {
        final data = d.data();
        msgs.add({'id': d.id, ...data});
        if (data['professorId'] is String) autores.add(data['professorId']);
      }

      for (final id in autores) {
        if (_nomePorUid.containsKey(id)) continue;
        try {
          final u = await _fs.getUserByUid(id);
          if (u != null) _nomePorUid[id] = u['nome'] ?? 'Professor';
        } catch (_) {}
      }

      msgs.sort((a, b) =>
          _millis(b['enviadaEm']).compareTo(_millis(a['enviadaEm'])));

      setState(() {
        _mensagens = msgs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar mensagens: $e';
        _loading = false;
      });
    }
  }

  int _millis(dynamic ts) {
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    if (ts is Map && ts['_seconds'] is int) return (ts['_seconds'] as int) * 1000;
    return 0;
  }

  List<String> _disciplinas() {
    final set = <String>{};
    for (final m in _mensagens) {
      final disc = (m['disciplina'] ?? '').toString();
      if (disc.isNotEmpty) set.add(disc);
    }
    final list = ['Todas', ...set.toList()..sort()];
    if (!list.contains(_filtroDisciplina)) _filtroDisciplina = 'Todas';
    return list;
  }

  List<Map<String, dynamic>> _aplicarFiltros() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final disc = _filtroDisciplina;

    return _mensagens.where((m) {
      final texto = (m['mensagem'] ?? '').toString().toLowerCase();
      final professor = _nomePorUid[m['professorId']]?.toLowerCase() ?? '';
      final d = (m['disciplina'] ?? '').toString();
      final okBusca = q.isEmpty || texto.contains(q) || professor.contains(q);
      final okDisc = disc == 'Todas' || d == disc;
      return okBusca && okDisc;
    }).toList();
  }

  bool _isNovo(int tsMillis) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - tsMillis) <= const Duration(days: 2).inMilliseconds;
  }

  Future<void> _enviarResposta(String professorId) async {
    final texto = _respostaCtrl.text.trim();
    if (texto.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('mensagens').add({
        'mensagem': texto,
        'alunoId': _auth.currentUser?.uid,
        'alunoRA': alunoRA,
        'professorId': professorId,
        'destinatario': professorId,
        'enviadaEm': DateTime.now(),
        'dataFormatada':
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      });

      _respostaCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resposta enviada ao professor.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar resposta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
                ? Center(
                    child: Text(_erro!,
                        style: const TextStyle(color: Colors.redAccent)))
                : Column(
                    children: [
                      _header(),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(child: _searchField()),
                            const SizedBox(width: 10),
                            _filtroDropdown(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(child: _listaMensagens()),
                    ],
                  ),
      ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Mensagens',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SizedBox(height: 2),
                Text('Comunicados e respostas',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ],
        ),
      );

  Widget _searchField() => TextField(
        controller: _searchCtrl,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Buscar mensagens...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffe6e6ee))),
        ),
      );

  Widget _filtroDropdown() {
    final itens = _disciplinas();
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        value: _filtroDisciplina,
        items: itens
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _filtroDisciplina = v ?? 'Todas'),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xffe6e6ee))),
        ),
      ),
    );
  }

  Widget _listaMensagens() {
    final dados = _aplicarFiltros();
    if (dados.isEmpty) {
      return const Center(
        child: Text('Nenhuma mensagem encontrada',
            style: TextStyle(color: Colors.black54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
      itemCount: dados.length,
      itemBuilder: (context, i) {
        final m = dados[i];
        final ts = _millis(m['enviadaEm']);
        final professor =
            _nomePorUid[m['professorId']] ?? 'Professor Desconhecido';
        final texto = (m['mensagem'] ?? '').toString();
        final data = m['dataFormatada'] ?? _date.format(DateTime.now());
        final novo = _isNovo(ts);

        return _MensagemCard(
          professor: professor,
          texto: texto,
          data: data,
          novo: novo,
          onResponder: () => _abrirDialogResposta(professor, m['professorId']),
        );
      },
    );
  }

  void _abrirDialogResposta(String professorNome, String professorId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Responder para $professorNome"),
        content: TextField(
          controller: _respostaCtrl,
          decoration:
              const InputDecoration(labelText: "Digite sua mensagem..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              _enviarResposta(professorId);
              Navigator.pop(context);
            },
            child: const Text("Enviar"),
          ),
        ],
      ),
    );
  }
}

/// CARD VISUAL DE MENSAGEM
class _MensagemCard extends StatelessWidget {
  final String professor;
  final String texto;
  final String data;
  final bool novo;
  final VoidCallback onResponder;

  const _MensagemCard({
    required this.professor,
    required this.texto,
    required this.data,
    required this.novo,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(professor,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(data,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              texto,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (novo)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Novo',
                        style:
                            TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onResponder,
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Responder'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
