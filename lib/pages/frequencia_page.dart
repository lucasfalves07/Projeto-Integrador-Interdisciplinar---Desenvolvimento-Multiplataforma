// ✅ lib/pages/frequencia_page.dart — LANÇAMENTO DE FREQUÊNCIA (PROFESSOR)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FrequenciaPage extends StatefulWidget {
  const FrequenciaPage({super.key});

  @override
  State<FrequenciaPage> createState() => _FrequenciaPageState();
}

class _FrequenciaPageState extends State<FrequenciaPage> {
  final _auth = FirebaseAuth.instance;
  bool _carregando = true;
  String? _turmaSelecionada;
  DateTime _dataSelecionada = DateTime.now();

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _alunos = [];
  final Map<String, bool> _presencas = {};

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  // ============================================================
  // 🔹 Carregar turmas do professor
  // ============================================================
  Future<void> _carregarTurmas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('turmas')
        .where('professorId', isEqualTo: uid)
        .get();

    _turmas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    if (_turmas.isNotEmpty) {
      _turmaSelecionada ??= _turmas.first['id'];
      await _carregarAlunos();
    }

    setState(() => _carregando = false);
  }

  // ============================================================
  // 🔹 Carregar alunos da turma
  // ============================================================
  Future<void> _carregarAlunos() async {
    if (_turmaSelecionada == null) return;

    setState(() => _carregando = true);
    final snap = await FirebaseFirestore.instance
        .collection('alunos')
        .where('turmaId', isEqualTo: _turmaSelecionada)
        .get();

    _alunos = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    // Carregar presença existente (se já houver)
    final df = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
    final freqSnap = await FirebaseFirestore.instance
        .collection('frequencias')
        .doc(_turmaSelecionada)
        .collection(df)
        .get();

    _presencas.clear();
    for (final doc in freqSnap.docs) {
      _presencas[doc.id] = doc['presente'] ?? false;
    }

    setState(() => _carregando = false);
  }

  // ============================================================
  // 🔹 Salvar presenças
  // ============================================================
  Future<void> _salvar() async {
    if (_turmaSelecionada == null) return;
    final db = FirebaseFirestore.instance;
    final df = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
    final batch = db.batch();
    final uid = _auth.currentUser?.uid ?? '';

    for (final aluno in _alunos) {
      final ra = aluno['id'];
      final ref = db
          .collection('frequencias')
          .doc(_turmaSelecionada)
          .collection(df)
          .doc(ra);

      batch.set(ref, {
        'presente': _presencas[ra] ?? false,
        'nome': aluno['nome'],
        'ra': ra,
        'turmaId': _turmaSelecionada,
        'professorId': uid,
        'data': df,
        'criadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Frequência salva com sucesso!')),
      );
    }
  }

  // ============================================================
  // 🔹 Interface
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamento de Frequência'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvar,
            tooltip: 'Salvar presença',
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _filtros(),
                  const SizedBox(height: 12),
                  Expanded(child: _listaAlunos()),
                ],
              ),
            ),
    );
  }

  Widget _filtros() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _turmaSelecionada,
            decoration: const InputDecoration(
              labelText: 'Turma',
              border: OutlineInputBorder(),
            ),
            items: _turmas
                .map((t) =>
                    DropdownMenuItem(value: t['id'], child: Text(t['nome'] ?? t['id'])))
                .toList(),
            onChanged: (v) async {
              setState(() => _turmaSelecionada = v);
              await _carregarAlunos();
            },
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('dd/MM/yyyy').format(_dataSelecionada)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dataSelecionada,
              firstDate: DateTime(2024, 1),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() => _dataSelecionada = picked);
              await _carregarAlunos();
            }
          },
        ),
      ],
    );
  }

  Widget _listaAlunos() {
    if (_alunos.isEmpty) {
      return const Center(child: Text('Nenhum aluno encontrado.'));
    }

    return ListView.builder(
      itemCount: _alunos.length,
      itemBuilder: (context, i) {
        final aluno = _alunos[i];
        final ra = aluno['id'];
        final nome = aluno['nome'] ?? '-';

        return CheckboxListTile(
          value: _presencas[ra] ?? false,
          onChanged: (v) => setState(() => _presencas[ra] = v ?? false),
          title: Text(nome),
          subtitle: Text('RA: $ra'),
        );
      },
    );
  }
}
