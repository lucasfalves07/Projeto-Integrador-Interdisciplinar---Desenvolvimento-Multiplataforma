import 'dart:convert';
import 'dart:html' as html; // para upload CSV no web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GerenciarAlunosPage extends StatefulWidget {
  const GerenciarAlunosPage({super.key});

  @override
  State<GerenciarAlunosPage> createState() => _GerenciarAlunosPageState();
}

class _GerenciarAlunosPageState extends State<GerenciarAlunosPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  late final String _uid;

  bool _loading = true;
  List<Map<String, dynamic>> _turmas = [];
  String? _turmaSelecionada;

  @override
  void initState() {
    super.initState();
    _uid = _auth.currentUser?.uid ?? '';
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    try {
      final qs = await _fire
          .collection('turmas')
          .where('professorId', isEqualTo: _uid)
          .get();
      setState(() {
        _turmas = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (_turmas.isNotEmpty) _turmaSelecionada = _turmas.first['id'];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAlunos() {
    if (_turmaSelecionada == null) {
      return const Stream.empty();
    }
    return _fire
        .collection('alunos')
        .where('turmaId', isEqualTo: _turmaSelecionada)
        .orderBy('nome')
        .snapshots();
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Alunos'),
        actions: [
          if (!_loading && _turmaSelecionada != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'novo') _abrirFormularioNovoAluno();
                if (v == 'csv') _importarCSV();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'novo',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.person_add),
                    title: Text('Novo aluno'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.upload_file),
                    title: Text('Importar CSV'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _turmas.isEmpty
              ? const Center(child: Text('Nenhuma turma vinculada.'))
              : Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButtonFormField<String>(
                        value: _turmaSelecionada,
                        decoration: const InputDecoration(
                          labelText: 'Turma',
                          border: OutlineInputBorder(),
                        ),
                        items: _turmas
                            .map((t) => DropdownMenuItem(
                                  value: t['id'],
                                  child: Text(t['nome'] ?? 'Turma'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _turmaSelecionada = v),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _streamAlunos(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snap.hasError) {
                            return Center(
                                child: Text('Erro: ${snap.error}',
                                    textAlign: TextAlign.center));
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(
                                child: Text('Nenhum aluno nesta turma.'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final data = docs[i].data();
                              final id = docs[i].id;
                              final nome = (data['nome'] ?? '-') as String;
                              final ra = (data['ra'] ?? '-') as String;
                              final email = (data['email'] ?? '-') as String;
                              final media = (data['media'] ?? 0).toDouble();

                              return Card(
                                elevation: 0.7,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Text(
                                      nome.isNotEmpty
                                          ? nome[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: Colors.black, fontSize: 18),
                                    ),
                                  ),
                                  title: Text(nome),
                                  subtitle: Text(
                                      'RA: $ra\nE-mail: $email\nMédia: ${media.toStringAsFixed(2)}'),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'editar') {
                                        _editarAluno(id, data);
                                      } else if (v == 'excluir') {
                                        _excluirAluno(id, nome);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: ListTile(
                                          dense: true,
                                          leading: Icon(Icons.edit),
                                          title: Text('Editar'),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'excluir',
                                        child: ListTile(
                                          dense: true,
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Excluir'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  // ------------------- CRUD -------------------

  Future<void> _abrirFormularioNovoAluno() async {
    final nomeCtrl = TextEditingController();
    final raCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Novo Aluno',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: raCtrl,
                decoration: const InputDecoration(
                    labelText: 'RA', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'E-mail', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                  onPressed: () async {
                    if (nomeCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Preencha o nome do aluno.')));
                      return;
                    }
                    try {
                      await _fire.collection('alunos').add({
                        'nome': nomeCtrl.text.trim(),
                        'ra': raCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'turmaId': _turmaSelecionada,
                        'professorId': _uid,
                        'media': 0,
                        'criadoEm': FieldValue.serverTimestamp(),
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Aluno adicionado com sucesso.')));
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editarAluno(String id, Map<String, dynamic> data) async {
    final nomeCtrl = TextEditingController(text: data['nome'] ?? '');
    final raCtrl = TextEditingController(text: data['ra'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editar Aluno',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: raCtrl,
                decoration: const InputDecoration(
                    labelText: 'RA', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                    labelText: 'E-mail', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar alterações'),
                  onPressed: () async {
                    await _fire.collection('alunos').doc(id).update({
                      'nome': nomeCtrl.text.trim(),
                      'ra': raCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Aluno atualizado com sucesso.')));
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _excluirAluno(String id, String nome) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir aluno'),
        content: Text('Tem certeza que deseja excluir "$nome"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await _fire.collection('alunos').doc(id).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Aluno removido.')));
  }

  // ------------------- CSV Import -------------------
  Future<void> _importarCSV() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Importação CSV disponível apenas na versão Web.')));
      return;
    }

    final input = html.FileUploadInputElement()..accept = '.csv';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;

    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;
    final content = reader.result as String;
    final linhas = const LineSplitter().convert(content);

    int adicionados = 0;
    for (var i = 1; i < linhas.length; i++) {
      final partes = linhas[i].split(',');
      if (partes.length < 2) continue;
      final nome = partes[0].trim();
      final ra = partes[1].trim();
      if (nome.isEmpty) continue;

      await _fire.collection('alunos').add({
        'nome': nome,
        'ra': ra,
        'turmaId': _turmaSelecionada,
        'professorId': _uid,
        'media': 0,
        'criadoEm': FieldValue.serverTimestamp(),
      });
      adicionados++;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Importação concluída: $adicionados alunos adicionados.')));
  }
}
