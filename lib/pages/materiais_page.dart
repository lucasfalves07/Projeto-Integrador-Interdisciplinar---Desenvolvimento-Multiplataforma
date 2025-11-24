// ======================================================================
//  MATERIAIS_PAGE — FINAL, 100% COMPATÍVEL COM SEU FIRESTORE
//  Salva em: disciplinas/{disciplinaId}/topicos/{topicoId}/materiais
// ======================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class MateriaisPage extends StatefulWidget {
  const MateriaisPage({super.key});

  @override
  State<MateriaisPage> createState() => _MateriaisPageState();
}

class _MateriaisPageState extends State<MateriaisPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _fs = FirestoreService();

  List<Map<String, dynamic>> _turmas = [];
  List<Map<String, dynamic>> _disciplinas = [];
  List<Map<String, dynamic>> _topicos = [];

  String? _turmaId;
  String? _disciplinaId;
  String? _topicoId;

  bool _loadingTurmas = true;
  bool _loadingDisciplinas = false;

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  // ================================================================
  // CARREGAR TURMAS
  // ================================================================
  Future<void> _carregarTurmas() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loadingTurmas = true);

    try {
      _turmas = await _fs.listarTurmasDoProfessor(uid);

      if (_turmas.isNotEmpty) {
        _turmaId = _turmas.first["id"];
        await _carregarDisciplinas();
      }
    } catch (_) {}

    setState(() => _loadingTurmas = false);
  }

  // ================================================================
  // CARREGAR DISCIPLINAS
  // ================================================================
  Future<void> _carregarDisciplinas() async {
    if (_turmaId == null) return;

    setState(() => _loadingDisciplinas = true);

    final turma = await _db.collection("turmas").doc(_turmaId).get();
    final discs = turma.data()?["disciplinas"] ?? [];

    _disciplinas =
        discs.map<Map<String, dynamic>>((d) => {"id": d["id"], "nome": d["nome"]}).toList();

    if (_disciplinas.isNotEmpty) {
      _disciplinaId = _disciplinas.first["id"];
      await _carregarTopicos();
    }

    setState(() => _loadingDisciplinas = false);
  }

  // ================================================================
  // CARREGAR TÓPICOS
  // ================================================================
  Future<void> _carregarTopicos() async {
    if (_disciplinaId == null) return;

    final snap = await _db
        .collection("disciplinas")
        .doc(_disciplinaId)
        .collection("topicos")
        .orderBy("ordem")
        .get();

    _topicos = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();

    _topicoId = _topicos.isNotEmpty ? _topicos.first["id"] : null;

    setState(() {});
  }

  // ================================================================
  // STREAM DOS MATERIAIS — CAMINHO ORIGINAL
  // ================================================================
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamMateriais() {
    if (_disciplinaId == null || _topicoId == null) {
      return const Stream.empty();
    }

    return _db
        .collection("disciplinas")
        .doc(_disciplinaId)
        .collection("topicos")
        .doc(_topicoId)
        .collection("materiais")
        .orderBy("criadoEm", descending: true)
        .snapshots();
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Materiais", style: TextStyle(color: Colors.black87)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Adicionar Material"),
        onPressed: _abrirDialogAdicionar,
      ),
      body: _loadingTurmas
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _dropTurmas(),
                _loadingDisciplinas
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator())
                    : _dropDisciplinas(),
                _dropTopicos(),
                Expanded(child: _listaMateriais()),
              ],
            ),
    );
  }

  // ================================================================
  // DROPDOWNS
  // ================================================================
  Widget _dropTurmas() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        value: _turmaId,
        decoration: _dec("Turma"),
        items: _turmas
            .map(
              (t) => DropdownMenuItem<String>(
                value: (t["id"]).toString(),
                child: Text(t["nome"].toString()),
              ),
            )
            .toList(),
        onChanged: (v) async {
          _turmaId = v;
          setState(() {});
          await _carregarDisciplinas();
        },
      ),
    );
  }

  Widget _dropDisciplinas() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        value: _disciplinaId,
        decoration: _dec("Disciplina"),
        items: _disciplinas
            .map(
              (d) => DropdownMenuItem<String>(
                value: d["id"].toString(),
                child: Text(d["nome"].toString()),
              ),
            )
            .toList(),
        onChanged: (v) async {
          _disciplinaId = v;
          await _carregarTopicos();
        },
      ),
    );
  }

  Widget _dropTopicos() {
    if (_topicos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text("Nenhum tópico cadastrado.",
            style: TextStyle(color: Colors.black54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        value: _topicoId,
        decoration: _dec("Tópico"),
        items: _topicos
            .map(
              (t) => DropdownMenuItem<String>(
                value: t["id"].toString(),
                child: Text(t["nome"]?.toString() ?? "Tópico"),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _topicoId = v),
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // ================================================================
  // LISTA DE MATERIAIS
  // ================================================================
  Widget _listaMateriais() {
    if (_topicoId == null) {
      return const Center(
        child: Text("Selecione um tópico para visualizar os materiais."),
      );
    }

    return StreamBuilder(
      stream: _streamMateriais(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text("Erro: ${snap.error}"),
          );
        }

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text("Nenhum material encontrado."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final m = doc.data();
            final titulo = (m["titulo"] ?? "Sem título").toString();
            final subtitulo =
                m["disciplinaNome"] ?? m["topicoNome"] ?? (m["tipo"] ?? "");

            return Card(
              elevation: 1,
              child: ListTile(
                onTap: () => _abrirLink(m["url"]?.toString()),
                leading: const Icon(Icons.attach_file, color: Colors.orange),
                title: Text(titulo),
                subtitle: Text(subtitulo.toString()),
                trailing: IconButton(
                  onPressed: () => _excluirMaterial(doc.id),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================================================================
  // ABRIR MATERIAL
  // ================================================================
  Future<void> _abrirLink(String? url) async {
    if (url == null) return;

    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ================================================================
  // DIALOG ADICIONAR MATERIAL
  // ================================================================
  Future<void> _abrirDialogAdicionar() async {
    if (_disciplinaId == null || _topicoId == null) return;

    final titulo = TextEditingController();
    final link = TextEditingController();
    PlatformFile? arquivo;
    bool uploading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setStateDialog) => AlertDialog(
          title: const Text("Adicionar Material"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titulo, decoration: _dec("Título")),
              const SizedBox(height: 10),
              TextField(controller: link, decoration: _dec("Link")),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      arquivo?.name ?? "Nenhum arquivo selecionado",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () async {
                      final r = await FilePicker.platform.pickFiles(withData: true);
                      if (r != null) setStateDialog(() => arquivo = r.files.first);
                    },
                  )
                ],
              ),
              if (uploading) const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: uploading
                  ? null
                  : () async {
                      if (titulo.text.trim().isEmpty) return;

                      String url = link.text.trim();
                      String tipo = "link";

                      if (arquivo != null) {
                        setStateDialog(() => uploading = true);

                        final filename =
                            "${DateTime.now().millisecondsSinceEpoch}_${arquivo!.name}";

                        final ref = FirebaseStorage.instance
                            .ref("materiais/${_auth.currentUser!.uid}/$filename");

                        final task = arquivo!.bytes != null
                            ? ref.putData(arquivo!.bytes!)
                            : ref.putFile(File(arquivo!.path!));

                        final snap = await task;
                        url = await snap.ref.getDownloadURL();
                        tipo = arquivo!.extension ?? "arquivo";
                      }

                      await _salvarMaterial(titulo.text, url, tipo);

                      if (!mounted) return;
                      Navigator.pop(ctx);
                    },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SALVAR MATERIAL (CORRETO AGORA)
  // ================================================================
  Future<void> _salvarMaterial(String titulo, String url, String tipo) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _turmaId == null || _disciplinaId == null) return;

    final dados = {
      "titulo": titulo,
      "url": url,
      "tipo": tipo,
      "criadoEm": FieldValue.serverTimestamp(),
      "professorId": uid,
      "turmaId": _turmaId,
      "turmaNome": _buscarNomeTurma(_turmaId),
      "disciplinaId": _disciplinaId,
      "disciplinaNome": _buscarNomeDisciplina(_disciplinaId),
      "topicoId": _topicoId,
      "topicoNome": _buscarNomeTopico(_topicoId),
    };

    final doc = _db.collection("materiais").doc();
    await doc.set({"id": doc.id, ...dados});

    final discRef = _db.collection("disciplinas").doc(_disciplinaId);
    await discRef.collection("materiais").doc(doc.id).set(dados);

    if (_topicoId != null) {
      await discRef
          .collection("topicos")
          .doc(_topicoId)
          .collection("materiais")
          .doc(doc.id)
          .set(dados);
    }
  }

  // ================================================================
  // EXCLUIR MATERIAL
  // ================================================================
  Future<void> _excluirMaterial(String id) async {
    if (_disciplinaId == null || _topicoId == null) return;

    await _db.collection("materiais").doc(id).delete();

    final discRef = _db.collection("disciplinas").doc(_disciplinaId);

    try {
      await discRef.collection("materiais").doc(id).delete();
    } catch (_) {}

    try {
      await discRef
          .collection("topicos")
          .doc(_topicoId)
          .collection("materiais")
          .doc(id)
          .delete();
    } catch (_) {}
  }

  String? _buscarNomeTurma(String? id) {
    if (id == null) return null;
    try {
      return _turmas.firstWhere((t) => t["id"].toString() == id)["nome"]?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _buscarNomeDisciplina(String? id) {
    if (id == null) return null;
    try {
      return _disciplinas
          .firstWhere((d) => d["id"].toString() == id)["nome"]
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  String? _buscarNomeTopico(String? id) {
    if (id == null) return null;
    try {
      return _topicos.firstWhere((t) => t["id"].toString() == id)["nome"]?.toString();
    } catch (_) {
      return null;
    }
  }
}