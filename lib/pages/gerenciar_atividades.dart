import 'dart:convert';
import 'dart:html' as html; // somente no Web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ============================================================
  // 🔹 Carrega turmas do professor
  // ============================================================
  Future<void> _carregarTurmas() async {
    try {
      final snap = await _fire
          .collection('turmas')
          .where('professorId', isEqualTo: _uid)
          .get();

      setState(() {
        _turmas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (_turmas.isNotEmpty) {
          _turmaSelecionada = _turmas.first['id'];
        }
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  // ============================================================
  // 🔹 Stream de alunos
  // ============================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamAlunos() {
    if (_turmaSelecionada == null) return const Stream.empty();

    return _fire
        .collection('alunos')
        .where('turmaId', isEqualTo: _turmaSelecionada)
        .orderBy('nome')
        .snapshots();
  }

  // ============================================================
  // 🔹 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Alunos'),
        actions: [
          if (!_loading && _turmaSelecionada != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'novo') _novoAluno();
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
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_turmas.isEmpty) {
      return const Center(child: Text('Nenhuma turma vinculada.'));
    }

    return Column(
      children: [
        // dropdown
        Padding(
          padding: const EdgeInsets.all(16),
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

        // lista de alunos
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _streamAlunos(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erro: ${snap.error}'));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('Nenhum aluno nesta turma.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final id = docs[i].id;
                  final data = docs[i].data();

                  final nome = data['nome'] ?? '-';
                  final ra = data['ra'] ?? '-';
                  final email = data['email'] ?? '-';
                  final media = (data['media'] ?? 0).toDouble();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(nome.isNotEmpty ? nome[0] : '?'),
                      ),
                      title: Text(nome),
                      subtitle: Text(
                        "RA: $ra\nE-mail: $email\nMédia: ${media.toStringAsFixed(2)}",
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'editar') _editarAluno(id, data);
                          if (v == 'excluir') _excluirAluno(id, nome);
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
                              leading: Icon(Icons.delete),
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
    );
  }

  // ============================================================
  // 🔹 CRUD – Novo aluno
  // ============================================================
  Future<void> _novoAluno() async {
    final nomeCtrl = TextEditingController();
    final raCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final padding = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Novo aluno',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Nome
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // RA
              TextField(
                controller: raCtrl,
                decoration: const InputDecoration(
                  labelText: 'RA',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Email
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),

              // button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Salvar"),
                  onPressed: () async {
                    if (nomeCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preencha o nome.')),
                      );
                      return;
                    }

                    await _fire.collection("alunos").add({
                      "nome": nomeCtrl.text.trim(),
                      "ra": raCtrl.text.trim(),
                      "email": emailCtrl.text.trim(),
                      "turmaId": _turmaSelecionada,
                      "professorId": _uid,
                      "media": 0,
                      "criadoEm": FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Aluno criado!')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 🔹 EDITAR aluno
  // ============================================================
  Future<void> _editarAluno(String id, Map<String, dynamic> data) async {
    final nomeCtrl = TextEditingController(text: data['nome'] ?? '');
    final raCtrl = TextEditingController(text: data['ra'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final padding = MediaQuery.of(context).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editar aluno',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  label: const Text("Salvar alterações"),
                  onPressed: () async {
                    final novoRa = raCtrl.text.trim();
                    final col = _fire.collection("alunos");

                    // RA ALTERADO → mover documento
                    if (novoRa.isNotEmpty && novoRa != id) {
                      await _fire.runTransaction((tx) async {
                        final oldRef = col.doc(id);
                        final oldSnap = await tx.get(oldRef);
                        final dadosAntigos =
                            oldSnap.data() as Map<String, dynamic>? ?? {};

                        final newRef = col.doc(novoRa);

                        tx.set(newRef, {
                          ...dadosAntigos,
                          "nome": nomeCtrl.text.trim(),
                          "ra": novoRa,
                          "email": emailCtrl.text.trim(),
                          "updatedAt": FieldValue.serverTimestamp(),
                        });

                        tx.delete(oldRef);
                      });
                    } else {
                      await col.doc(id).set({
                        "nome": nomeCtrl.text.trim(),
                        "ra": novoRa,
                        "email": emailCtrl.text.trim(),
                        "updatedAt": FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    }

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Aluno atualizado.")),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 🔹 EXCLUIR aluno
  // ============================================================
  Future<void> _excluirAluno(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir aluno"),
        content: Text('Deseja excluir "$nome"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _fire.collection("alunos").doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aluno removido.")),
    );
  }

  // ============================================================
  // 🔹 Importar CSV
  // ============================================================
  Future<void> _importarCSV() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CSV disponível apenas no Web.")),
      );
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

      await _fire.collection("alunos").doc(ra).set({
        "nome": nome,
        "ra": ra,
        "turmaId": _turmaSelecionada,
        "professorId": _uid,
        "media": 0,
        "criadoEm": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      adicionados++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Importação concluída: $adicionados alunos.")),
    );
  }
}