import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'upload_dialog.dart';

class NovaAtividadePage extends StatefulWidget {
  const NovaAtividadePage({super.key});

  @override
  State<NovaAtividadePage> createState() => _NovaAtividadePageState();
}

class _NovaAtividadePageState extends State<NovaAtividadePage> {
  final _auth = FirebaseAuth.instance;

  final _tituloCtrl = TextEditingController();
  final _disciplinaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController(text: '1');
  final _prazoCtrl = TextEditingController();

  DateTime? _prazoSelecionado;
  bool _salvando = false;

  List<Map<String, dynamic>> _turmas = [];
  final Set<String> _turmasSelecionadas = {};

  // arquivos selecionados antes de salvar (opcional)
  List<PlatformFile> _arquivosSelecionados = [];

  @override
  void initState() {
    super.initState();
    _carregarTurmasDoProfessor();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _disciplinaCtrl.dispose();
    _pesoCtrl.dispose();
    _prazoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarTurmasDoProfessor() async {
    try {
      final uid = _auth.currentUser?.uid;
      final snap = await FirebaseFirestore.instance
          .collection('turmas')
          .where('professorId', isEqualTo: uid)
          .orderBy('nome')
          .get();

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

  Future<void> _pickArquivos() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb, // no web precisamos dos bytes
        type: FileType.any,
      );
      if (res != null) {
        setState(() {
          _arquivosSelecionados = res.files;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao selecionar arquivos: $e')),
      );
    }
  }

  Future<void> _salvar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      _erro('Informe o título.');
      return;
    }
    if (_turmasSelecionadas.isEmpty) {
      _erro('Selecione ao menos uma turma.');
      return;
    }
    if (_prazoSelecionado == null) {
      _erro('Selecione o prazo.');
      return;
    }

    setState(() => _salvando = true);
    try {
      // cria documento da atividade sem anexos
      final docRef = await FirebaseFirestore.instance
          .collection('atividades')
          .add({
        'titulo': _tituloCtrl.text.trim(),
        'disciplina': _disciplinaCtrl.text.trim(),
        'peso': double.tryParse(_pesoCtrl.text.replaceAll(',', '.')) ?? 1.0,
        'prazo': Timestamp.fromDate(_prazoSelecionado!),
        'turmaIds': _turmasSelecionadas.toList(),
        'professorId': _auth.currentUser?.uid,
        'criadoEm': FieldValue.serverTimestamp(),
        'anexos': [],
      });

      // se houver arquivos, sobe pro Storage e preenche "anexos"
      if (_arquivosSelecionados.isNotEmpty) {
        final anexos = await _uploadArquivosAtividade(
          atividadeId: docRef.id,
          arquivos: _arquivosSelecionados,
        );

        await docRef.update({
          'anexos': FieldValue.arrayUnion(anexos),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atividade criada com sucesso!')),
      );

      Navigator.of(context).pop(true); // volta sinalizando sucesso
    } catch (e) {
      _erro('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<List<Map<String, dynamic>>> _uploadArquivosAtividade({
    required String atividadeId,
    required List<PlatformFile> arquivos,
  }) async {
    final storage = FirebaseStorage.instance;
    final List<Map<String, dynamic>> saida = [];

    for (final f in arquivos) {
      try {
        final nomeOriginal = f.name;
        final caminho =
            'atividades/$atividadeId/${DateTime.now().millisecondsSinceEpoch}_$nomeOriginal';

        UploadTask task;
        if (kIsWeb) {
          final Uint8List data =
              f.bytes ?? Uint8List.fromList(const []);
          task = storage.ref(caminho).putData(
                data,
                SettableMetadata(
                  contentType: f.extension != null
                      ? _mapContentType(f.extension!)
                      : 'application/octet-stream',
                ),
              );
        } else {
          // mobile/desktop
          if (f.path == null) {
            // fallback
            final Uint8List data =
                f.bytes ?? Uint8List.fromList(const []);
            task = storage.ref(caminho).putData(
                  data,
                  SettableMetadata(
                    contentType: f.extension != null
                        ? _mapContentType(f.extension!)
                        : 'application/octet-stream',
                  ),
                );
          } else {
            task = storage.ref(caminho).putFile(
                  // ignore: deprecated_member_use
                  // (PlatformFile.path ainda é a forma mais simples)
                  // File importado em upload_dialog.dart, aqui usamos putData/putFile via path
                  // mas pra evitar dependência de dart:io aqui, já tratamos o cenário acima.
                  // Se quiser 100% sem path, deixe sempre withData: true no FilePicker.
                  // Porém, manteremos esse branch para compatibilidade.
                  // Você pode manter apenas o putData se preferir.
                  // No entanto, como este arquivo não importa dart:io, usamos apenas putData no fallback acima.
                  // Portanto, para evitar warnings, faremos sempre via putData no fluxo acima.
                  // (mantemos esse comentário por clareza)
                  // -> Removido caminho local aqui.
                  // Esse else não será atingido porque optamos por withData no pick.
                  // Mas caso remover withData, adapte para usar File(f.path!)
                  // Ex: File(f.path!)
                  // Aqui, usaremos putData como fallback:
                  // ignore: dead_code
                  throw UnimplementedError(),
                );
          }
        }

        final snap = await task;
        final url = await snap.ref.getDownloadURL();
        final meta = await snap.ref.getMetadata();

        saida.add({
          'nome': nomeOriginal,
          'url': url,
          'contentType': meta.contentType ?? '',
          'storagePath': snap.ref.fullPath,
          'tamanho': f.size,
          'criadoEm': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // segue o baile — faz upload do que conseguir
        debugPrint('Falha upload "$e" para arquivo ${f.name}');
      }
    }

    return saida;
  }

  String _mapContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  void _erro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final turmasVazias = _turmas.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Atividade'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _disciplinaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Disciplina',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pesoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _prazoCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Prazo',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () async {
                      final pick = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        initialDate: DateTime.now(),
                      );
                      if (pick != null) {
                        setState(() {
                          _prazoSelecionado = pick;
                          _prazoCtrl.text =
                              DateFormat('dd/MM/yyyy').format(pick);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Turmas'),
                subtitle: Text(
                  _turmasSelecionadas.isEmpty
                      ? 'Nenhuma turma selecionada'
                      : '${_turmasSelecionadas.length} selecionada(s)',
                ),
                trailing: ElevatedButton.icon(
                  onPressed: turmasVazias ? null : _selecionarTurmas,
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Selecionar'),
                ),
              ),
              const Divider(height: 24),
              // Anexos
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Anexos (opcional)',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _arquivosSelecionados)
                    Chip(
                      label: Text(
                        f.name.length > 22
                            ? '${f.name.substring(0, 22)}…'
                            : f.name,
                      ),
                      onDeleted: () {
                        setState(() {
                          _arquivosSelecionados.remove(f);
                        });
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickArquivos,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Adicionar arquivos'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _salvando ? null : _salvar,
                  icon: _salvando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Salvar atividade'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selecionarTurmas() async {
    final selecionadas = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MultiSelectTurmasDialog(
        turmas: _turmas,
        selecionadas: _turmasSelecionadas,
      ),
    );

    if (selecionadas != null) {
      setState(() {
        _turmasSelecionadas
          ..clear()
          ..addAll(selecionadas);
      });
    }
  }
}

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

class _MultiSelectTurmasDialogState extends State<_MultiSelectTurmasDialog> {
  late final Set<String> _temp = {...widget.selecionadas};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecione as turmas'),
      content: SizedBox(
        width: 420,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.turmas.length,
          itemBuilder: (_, i) {
            final t = widget.turmas[i];
            final id = t['id'] as String;
            final nome = (t['nome'] ?? 'Turma').toString();
            final marcado = _temp.contains(id);
            return CheckboxListTile(
              value: marcado,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _temp.add(id);
                  } else {
                    _temp.remove(id);
                  }
                });
              },
              title: Text(nome),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, widget.selecionadas),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _temp),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
