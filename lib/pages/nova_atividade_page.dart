// ---------------------------------------------------------------
// NOVA ATIVIDADE — 100% COMPATÍVEL COM atividades_page.dart
// ---------------------------------------------------------------

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class NovaAtividadePage extends StatefulWidget {
  const NovaAtividadePage({super.key});

  @override
  State<NovaAtividadePage> createState() => _NovaAtividadePageState();
}

class _NovaAtividadePageState extends State<NovaAtividadePage> {
  final _auth = FirebaseAuth.instance;

  final _tituloCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  final _disciplinaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController(text: "1");
  final _maxCtrl = TextEditingController(text: "10");
  final _bimestreCtrl = TextEditingController(text: "1º Bimestre");
  final _prazoCtrl = TextEditingController();

  DateTime? _prazoSelecionado;
  bool _salvando = false;

  List<Map<String, dynamic>> _turmas = [];
  final Set<String> _turmasSelecionadas = {};

  List<PlatformFile> _arquivosSelecionados = [];

  @override
  void initState() {
    super.initState();
    _carregarTurmasDoProfessor();
  }

  Future<void> _carregarTurmasDoProfessor() async {
    try {
      final uid = _auth.currentUser?.uid;

      final snap = await FirebaseFirestore.instance
          .collection("turmas")
          .where("professorId", isEqualTo: uid)
          .orderBy("nome")
          .get();

      setState(() {
        _turmas = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
      });
    } catch (e) {
      _erro("Erro ao carregar turmas: $e");
    }
  }

  Future<void> _pickArquivos() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (res != null) {
        setState(() => _arquivosSelecionados = res.files);
      }
    } catch (e) {
      _erro("Erro ao selecionar arquivos: $e");
    }
  }

  Future<void> _salvar() async {
    if (_tituloCtrl.text.trim().isEmpty) return _erro("Informe o título.");
    if (_disciplinaCtrl.text.trim().isEmpty) return _erro("Informe o ID da disciplina.");
    if (_turmasSelecionadas.isEmpty) return _erro("Selecione ao menos uma turma.");
    if (_prazoSelecionado == null) return _erro("Selecione o prazo.");

    setState(() => _salvando = true);

    try {
      final uid = _auth.currentUser!.uid;
      final peso = double.tryParse(_pesoCtrl.text.replaceAll(",", ".")) ?? 1;
      final max = double.tryParse(_maxCtrl.text.replaceAll(",", ".")) ?? 10;

      for (final turmaId in _turmasSelecionadas) {
        final agora = DateTime.now().millisecondsSinceEpoch;

        final docRef = FirebaseFirestore.instance
            .collection("atividades")
            .doc("A$agora-$turmaId");

        await docRef.set({
          "id": "A$agora-$turmaId",
          "titulo": _tituloCtrl.text.trim(),
          "descricao": _descricaoCtrl.text.trim(),
          "bimestre": _bimestreCtrl.text.trim(),
          "max": max,
          "peso": peso,
          "disciplinaId": _disciplinaCtrl.text.trim(),
          "professorId": uid,
          "turmaId": turmaId,
          "criadoEm": FieldValue.serverTimestamp(),
          "criadoEmMs": agora,
          "prazo": Timestamp.fromDate(_prazoSelecionado!),
          "arquivoUrl": null,
          "arquivoNome": null,
          "anexos": [],
        });

        if (_arquivosSelecionados.isNotEmpty) {
          final anexos = await _uploadArquivosAtividade(
            atividadeId: docRef.id,
            arquivos: _arquivosSelecionados,
          );

          await docRef.update({
            "anexos": FieldValue.arrayUnion(anexos),
          });
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Atividade criada com sucesso!")),
      );
    } catch (e) {
      _erro("Erro ao salvar atividade: $e");
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<List<Map<String, dynamic>>> _uploadArquivosAtividade({
    required String atividadeId,
    required List<PlatformFile> arquivos,
  }) async {
    final storage = FirebaseStorage.instance;
    List<Map<String, dynamic>> saida = [];

    for (final file in arquivos) {
      try {
        final path =
            "atividades/$atividadeId/${DateTime.now().millisecondsSinceEpoch}_${file.name}";

        UploadTask upload;

        if (kIsWeb || file.path == null) {
          upload = storage.ref(path).putData(
                file.bytes!,
                SettableMetadata(
                  contentType: _mapContentType(file.extension ?? ""),
                ),
              );
        } else {
          upload = storage.ref(path).putData(
                file.bytes!,
                SettableMetadata(
                  contentType: _mapContentType(file.extension ?? ""),
                ),
              );
        }

        final snap = await upload;
        final url = await snap.ref.getDownloadURL();

        saida.add({
          "nome": file.name,
          "url": url,
          "storagePath": snap.ref.fullPath,
          "contentType": snap.metadata?.contentType ?? "",
          "tamanho": file.size,
          "criadoEm": FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint("Erro ao enviar arquivo: $e");
      }
    }

    return saida;
  }

  String _mapContentType(String ext) {
    switch (ext.toLowerCase()) {
      case "pdf":
        return "application/pdf";
      case "jpg":
      case "jpeg":
        return "image/jpeg";
      case "png":
        return "image/png";
      case "mp4":
        return "video/mp4";
      case "doc":
        return "application/msword";
      case "docx":
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
      default:
        return "application/octet-stream";
    }
  }

  void _erro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(title: const Text("Nova Atividade")),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: "Título",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _descricaoCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Descrição (opcional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _disciplinaCtrl,
                decoration: const InputDecoration(
                  labelText: "ID da disciplina (disciplinaId)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _pesoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Peso",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nota máxima",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _bimestreCtrl,
                decoration: const InputDecoration(
                  labelText: "Bimestre",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _prazoCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Prazo",
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final pick = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );

                  if (pick != null) {
                    setState(() {
                      _prazoSelecionado = pick;
                      _prazoCtrl.text = DateFormat("dd/MM/yyyy").format(pick);
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              ListTile(
                title: const Text("Turmas"),
                subtitle: Text(
                  _turmasSelecionadas.isEmpty
                      ? "Nenhuma turma selecionada"
                      : "${_turmasSelecionadas.length} selecionada(s)",
                ),
                trailing: ElevatedButton(
                  onPressed: _turmas.isEmpty ? null : _selecionarTurmas,
                  child: const Text("Selecionar"),
                ),
              ),

              const Divider(),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Anexos",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 6,
                children: [
                  for (final f in _arquivosSelecionados)
                    Chip(
                      label: Text(f.name),
                      onDeleted: () {
                        setState(() => _arquivosSelecionados.remove(f));
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickArquivos,
                    icon: const Icon(Icons.attach_file),
                    label: const Text("Adicionar arquivos"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.save),
                  label: const Text("Salvar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selecionarTurmas() async {
    final res = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MultiSelectTurmasDialog(
        turmas: _turmas,
        selecionadas: _turmasSelecionadas,
      ),
    );

    if (res != null) {
      setState(() {
        _turmasSelecionadas
          ..clear()
          ..addAll(res);
      });
    }
  }
}

// ---------------------------------------------------------------
// DIALOG MULTISELECT TURMAS
// ---------------------------------------------------------------

class _MultiSelectTurmasDialog extends StatefulWidget {
  final List<Map<String, dynamic>> turmas;
  final Set<String> selecionadas;

  const _MultiSelectTurmasDialog({
    required this.turmas,
    required this.selecionadas,
  });

  @override
  State<_MultiSelectTurmasDialog> createState() =>
      _MultiSelectTurmasDialogState();
}

class _MultiSelectTurmasDialogState
    extends State<_MultiSelectTurmasDialog> {
  late final Set<String> _temp = {...widget.selecionadas};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Selecione as turmas"),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.turmas.length,
          itemBuilder: (_, i) {
            final t = widget.turmas[i];
            final id = t["id"];
            final nome = t["nome"] ?? "Turma";

            return CheckboxListTile(
              value: _temp.contains(id),
              title: Text(nome),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _temp.add(id);
                  } else {
                    _temp.remove(id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.pop(context, widget.selecionadas),
        ),
        ElevatedButton(
          child: const Text("Confirmar"),
          onPressed: () => Navigator.pop(context, _temp),
        ),
      ],
    );
  }
}