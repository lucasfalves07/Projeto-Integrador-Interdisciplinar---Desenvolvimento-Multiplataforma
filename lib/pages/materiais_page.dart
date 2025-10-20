// lib/pages/materiais_page.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// Se você já tem um service para listar turmas do professor,
/// pode manter o import. Caso não tenha, comente a linha abaixo
/// e usamos o _carregarTurmasDoProfessor() local (já implementado).
// import 'package:poliedro_flutter/services/firestore_service.dart';

class MateriaisPage extends StatefulWidget {
  const MateriaisPage({super.key});

  @override
  State<MateriaisPage> createState() => _MateriaisPageState();
}

class _MateriaisPageState extends State<MateriaisPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Se você já usa um service, pode descomentar e trocar nas chamadas:
  // final FirestoreService _firestoreService = FirestoreService();

  /// Form controllers
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _disciplinaController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  /// Upload state
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  PlatformFile? _arquivoSelecionado;

  /// Turmas (cache)
  List<Map<String, dynamic>> _turmasDoProfessor = [];
  List<String> _turmasSelecionadas = [];

  /// Filtros da listagem
  String? _filtroTurmaId; // se null => todas
  String _filtroDisciplina = '';

  /// Carregamento de turmas
  bool _carregandoTurmas = true;

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _disciplinaController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _carregarTurmas() async {
    if (currentUser == null) {
      setState(() => _carregandoTurmas = false);
      return;
    }

    try {
      // Se tiver FirestoreService:
      // final turmas = await _firestoreService.listarTurmasDoProfessor(currentUser!.uid);

      // Sem service: consulta direta
      final qs = await FirebaseFirestore.instance
          .collection('turmas')
          .where('professorId', isEqualTo: currentUser!.uid)
          .get();

      final turmas = qs.docs
          .map((d) => {
                'id': d.id,
                'nome': (d.data()['nome'] ?? 'Turma') as String,
              })
          .toList();

      setState(() {
        _turmasDoProfessor = turmas;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar turmas: $e')),
      );
    } finally {
      if (mounted) setState(() => _carregandoTurmas = false);
    }
  }

  // ---------------------------
  // STREAM de materiais (com filtros)
  // ---------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _streamMateriais() {
    final base = FirebaseFirestore.instance
        .collection('materiais')
        .where('professorId', isEqualTo: currentUser!.uid);

    // Vamos aplicar filtro por turma (server-side) quando possível
    // e disciplina (client-side) para permitir contains/case-insensitive.
    if (_filtroTurmaId != null && _filtroTurmaId!.isNotEmpty) {
      return base
          .where('turmasDesignadas', arrayContains: _filtroTurmaId)
          .orderBy('dataUpload', descending: true)
          .snapshots();
    }
    return base.orderBy('dataUpload', descending: true).snapshots();
  }

  // ---------------------------
  // UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Usuário não autenticado")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Materiais"),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Novo Material"),
        onPressed: () => _mostrarDialogMaterial(context),
      ),
      body: Column(
        children: [
          _filtros(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _streamMateriais(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    _carregandoTurmas) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                    'Erro: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ));
                }

                var materiais = snapshot.data?.docs ?? [];

                // Filtro por disciplina (client-side)
                if (_filtroDisciplina.trim().isNotEmpty) {
                  final query = _filtroDisciplina.trim().toLowerCase();
                  materiais = materiais.where((doc) {
                    final m = doc.data();
                    final disc = (m['disciplina'] ?? '').toString().toLowerCase();
                    final titulo = (m['titulo'] ?? '').toString().toLowerCase();
                    return disc.contains(query) || titulo.contains(query);
                  }).toList();
                }

                if (materiais.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        "Nenhum material encontrado.\nUse o botão “Novo Material” para adicionar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: materiais.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ref = materiais[index];
                    final material =
                        (ref.data() ?? <String, dynamic>{}) as Map<String, dynamic>;
                    final id = ref.id;

                    final titulo = (material["titulo"] ?? "") as String;
                    final disciplina = (material["disciplina"] ?? "") as String;
                    final url = (material["url"] ?? "") as String;
                    final data = (material["dataUpload"] is Timestamp)
                        ? (material["dataUpload"] as Timestamp).toDate()
                        : null;
                    final status = (material["status"] ?? "ready").toString();
                    final fileName = (material["fileName"] ?? "") as String;
                    final turmas = (material["turmasDesignadas"] as List?)?.cast<String>() ?? [];
                    final tipo = (material["type"] ?? "") as String;
                    final path = (material["path"] ?? "") as String;

                    final isPdf = fileName.toLowerCase().endsWith(".pdf") ||
                        url.toLowerCase().contains(".pdf");

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título + menu
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isPdf
                                        ? Icons.picture_as_pdf
                                        : _iconByMime(tipo, fileName),
                                    color: Colors.orange,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    titulo,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    switch (value) {
                                      case "open":
                                        _abrirLink(url);
                                        break;
                                      case "edit":
                                        _mostrarDialogMaterial(
                                          context,
                                          materialId: id,
                                          dados: material,
                                        );
                                        break;
                                      case "share":
                                        _copiarLink(url);
                                        break;
                                      case "delete":
                                        _confirmarExclusaoMaterial(
                                          context,
                                          id,
                                          titulo,
                                          storagePath: path,
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: "open",
                                      enabled: status == "ready" && url.isNotEmpty,
                                      child: _menuItem(Icons.open_in_new, "Abrir"),
                                    ),
                                    PopupMenuItem(
                                      value: "edit",
                                      child: _menuItem(Icons.edit, "Editar"),
                                    ),
                                    PopupMenuItem(
                                      value: "share",
                                      enabled: status == "ready" && url.isNotEmpty,
                                      child: _menuItem(Icons.share, "Copiar link"),
                                    ),
                                    PopupMenuItem(
                                      value: "delete",
                                      child: _menuItem(Icons.delete, "Excluir"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Disciplina + Data + Status
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (disciplina.isNotEmpty)
                                  _ChipInfo(icon: Icons.menu_book, label: disciplina),
                                if (data != null)
                                  _ChipInfo(
                                    icon: Icons.calendar_month,
                                    label:
                                        "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
                                  ),
                                if (status == "uploading")
                                  _ChipInfo(
                                    icon: Icons.cloud_upload,
                                    label: 'Enviando...',
                                    color: Colors.blueGrey.shade50,
                                  ),
                                if (status == "error")
                                  _ChipInfo(
                                    icon: Icons.error_outline,
                                    label: 'Falha no upload',
                                    color: Colors.red.shade50,
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),
                            // Turmas
                            if (turmas.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: turmas
                                    .map((t) => Chip(
                                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                          visualDensity: VisualDensity.compact,
                                          label: Text(_nomeTurma(t)),
                                        ))
                                    .toList(),
                              ),

                            if (status == "uploading") ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                minHeight: 5,
                                backgroundColor: const Color(0xFFECECEC),
                              ),
                              const SizedBox(height: 6),
                            ],
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

  // ---------------------------
  // Filtros (turma/disciplina)
  // ---------------------------
  Widget _filtros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Filtro por Turma
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filtroTurmaId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por turma',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas as turmas'),
                    ),
                    ..._turmasDoProfessor.map(
                      (t) => DropdownMenuItem<String>(
                        value: t['id'] as String,
                        child: Text(t['nome'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filtroTurmaId = v),
                ),
              ),
              const SizedBox(width: 12),
              // Filtro por Disciplina/Título
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por disciplina/título',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filtroDisciplina = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Dialog de criar/editar
  // ---------------------------
  Future<void> _mostrarDialogMaterial(BuildContext context,
      {String? materialId, Map<String, dynamic>? dados}) async {
    final isEdit = materialId != null;

    _tituloController.text = dados?["titulo"] ?? "";
    _disciplinaController.text = dados?["disciplina"] ?? "";
    _urlController.text = dados?["url"] ?? "";
    _arquivoSelecionado = null;
    _uploadProgress = 0.0;
    _turmasSelecionadas = List<String>.from(dados?["turmasDesignadas"] ?? []);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? "Editar Material" : "Adicionar Material"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _tituloController,
                      decoration: const InputDecoration(labelText: "Título *"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _disciplinaController,
                      decoration:
                          const InputDecoration(labelText: "Disciplina (opcional)"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: "Link externo (opcional)",
                        hintText: "Ex: https://exemplo.com/video",
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text("Selecione as turmas:",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (_turmasDoProfessor.isEmpty)
                      const Text("Nenhuma turma encontrada."),
                    ..._turmasDoProfessor.map((t) {
                      final id = t["id"] as String;
                      final nome = (t["nome"] ?? "Sem nome") as String;
                      final selecionada = _turmasSelecionadas.contains(id);
                      return CheckboxListTile(
                        dense: true,
                        value: selecionada,
                        onChanged: (val) {
                          setStateDialog(() {
                            if (val == true) {
                              _turmasSelecionadas.add(id);
                            } else {
                              _turmasSelecionadas.remove(id);
                            }
                          });
                        },
                        title: Text(nome),
                      );
                    }).toList(),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _arquivoSelecionado == null
                                ? "Nenhum arquivo selecionado"
                                : _arquivoSelecionado!.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Selecionar arquivo',
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              withData: true,
                              type: FileType.any,
                            );
                            if (result != null) {
                              setStateDialog(() {
                                _arquivoSelecionado = result.files.first;
                              });
                            }
                          },
                          icon:
                              const Icon(Icons.attach_file, color: Colors.orange),
                        ),
                      ],
                    ),
                    if (_isUploading) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _uploadProgress == 0 ? null : _uploadProgress,
                        minHeight: 5,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _uploadProgress == 0
                            ? "Preparando upload..."
                            : "${(_uploadProgress * 100).toStringAsFixed(0)}% enviado",
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isUploading ? null : () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: _isUploading
                      ? null
                      : () async {
                          await _salvarOuEditarMaterial(
                            context,
                            setStateDialog,
                            materialId: materialId,
                            dadosAntigos: dados,
                          );
                        },
                  child: _isUploading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? "Salvar Alterações" : "Salvar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------
  // Salvar/Editar + Upload
  // ---------------------------
  Future<void> _salvarOuEditarMaterial(
    BuildContext context,
    void Function(void Function()) setStateDialog, {
    String? materialId,
    Map<String, dynamic>? dadosAntigos,
  }) async {
    if (currentUser == null) return;

    final titulo = _tituloController.text.trim();
    final disciplina = _disciplinaController.text.trim();
    final urlExterno = _urlController.text.trim();

    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Digite o título do material.")),
      );
      return;
    }
    if (_turmasSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione pelo menos uma turma.")),
      );
      return;
    }

    setStateDialog(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    final uid = currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection("materiais")
        .doc(materialId ?? FirebaseFirestore.instance.collection("materiais").doc().id);

    try {
      final String oldPath = (dadosAntigos?['path'] ?? '') as String;

      // Dados base
      Map<String, dynamic> dados = {
        "titulo": titulo,
        "disciplina": disciplina,
        "url": urlExterno, // pode ser sobrescrito pelo upload
        "professorId": uid,
        "turmasDesignadas": _turmasSelecionadas,
        "fileName": _arquivoSelecionado?.name ?? (dadosAntigos?['fileName'] ?? ''),
        "fileSize": _arquivoSelecionado?.size ?? (dadosAntigos?['fileSize'] ?? 0),
        "type": _arquivoSelecionado != null
            ? _inferContentType(_arquivoSelecionado!.name)
            : (dadosAntigos?['type'] ?? ''),
        "path": dadosAntigos?['path'] ?? '',
        "status": _arquivoSelecionado != null ? "uploading" : "ready",
        "updatedAt": FieldValue.serverTimestamp(),
        "dataUpload": dadosAntigos?['dataUpload'] ?? FieldValue.serverTimestamp(),
      };

      if (materialId == null) {
        await docRef.set(dados);
      } else {
        await docRef.set(dados, SetOptions(merge: true));
      }

      String urlFinal = urlExterno;

      // Se o usuário escolheu novo arquivo, faz upload
      if (_arquivoSelecionado != null) {
        // Se havia um arquivo anterior, opcionalmente apagar depois (boa prática)
        // Obs: só apagamos após upload OK, para não deixar sem arquivo em caso de falha
        final path = "materiais/$uid/${DateTime.now().millisecondsSinceEpoch}_${_arquivoSelecionado!.name}";
        final storageRef = FirebaseStorage.instance.ref().child(path);
        final contentType = _inferContentType(_arquivoSelecionado!.name);
        final metadata = SettableMetadata(contentType: contentType);

        final Uint8List bytes = _arquivoSelecionado!.bytes!;
        final uploadTask = storageRef.putData(bytes, metadata);

        uploadTask.snapshotEvents.listen((TaskSnapshot snap) {
          final total = snap.totalBytes;
          final transferred = snap.bytesTransferred;
          final prog = total > 0 ? transferred / total : 0.0;
          setStateDialog(() => _uploadProgress = prog);
        });

        final snapshot = await uploadTask;
        urlFinal = await snapshot.ref.getDownloadURL();

        // Atualiza doc com dados finais do arquivo
        await docRef.update({
          "url": urlFinal,
          "status": "ready",
          "path": path,
          "type": contentType,
          "fileName": _arquivoSelecionado!.name,
          "fileSize": _arquivoSelecionado!.size,
        });

        // Se havia um arquivo anterior, apaga
        if (oldPath.isNotEmpty && oldPath != path) {
          try {
            await FirebaseStorage.instance.ref(oldPath).delete();
          } catch (_) {
            // Ignora erro ao deletar antigo
          }
        }
      }

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(materialId == null
              ? "Material “$titulo” adicionado!"
              : "Material “$titulo” atualizado com sucesso!"),
        ),
      );
    } catch (e) {
      debugPrint("❌ Erro ao salvar material: $e");
      try {
        await docRef.update({"status": "error"});
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar material: $e")),
      );
    } finally {
      if (mounted) {
        setStateDialog(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // ---------------------------
  // Helpers
  // ---------------------------
  String _nomeTurma(String turmaId) {
    final idx = _turmasDoProfessor.indexWhere((t) => t['id'] == turmaId);
    if (idx == -1) return turmaId;
    return (_turmasDoProfessor[idx]['nome'] ?? turmaId) as String;
  }

  IconData _iconByMime(String type, String fileName) {
    final lower = fileName.toLowerCase();
    if (type.contains('pdf') || lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (type.startsWith('image/') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) return Icons.image;
    if (type.startsWith('video/') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv')) return Icons.movie;
    if (type.startsWith('audio/') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) return Icons.audiotrack;
    if (lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.odt')) return Icons.description;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow;
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) return Icons.grid_on;
    return Icons.insert_drive_file;
  }

  String _inferContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith(".pdf")) return "application/pdf";
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
    if (lower.endsWith(".gif")) return "image/gif";
    if (lower.endsWith(".webp")) return "image/webp";
    if (lower.endsWith(".mp4")) return "video/mp4";
    if (lower.endsWith(".mov")) return "video/quicktime";
    if (lower.endsWith(".mkv")) return "video/x-matroska";
    if (lower.endsWith(".mp3")) return "audio/mpeg";
    if (lower.endsWith(".wav")) return "audio/wav";
    if (lower.endsWith(".m4a")) return "audio/mp4";
    if (lower.endsWith(".doc")) return "application/msword";
    if (lower.endsWith(".docx")) {
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    }
    if (lower.endsWith(".ppt")) return "application/vnd.ms-powerpoint";
    if (lower.endsWith(".pptx")) {
      return "application/vnd.openxmlformats-officedocument.presentationml.presentation";
    }
    if (lower.endsWith(".xls")) return "application/vnd.ms-excel";
    if (lower.endsWith(".xlsx")) {
      return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    }
    if (lower.endsWith(".csv")) return "text/csv";
    if (lower.endsWith(".txt")) return "text/plain";
    return "application/octet-stream";
  }

  Future<void> _copiarLink(String url) async {
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Link copiado para a área de transferência.")),
    );
  }

  Future<void> _confirmarExclusaoMaterial(
    BuildContext context,
    String id,
    String titulo, {
    String storagePath = '',
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir Material"),
        content: Text("Deseja realmente excluir o material “$titulo”?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1) Exclui do Storage (se tiver path salvo)
        if (storagePath.isNotEmpty) {
          try {
            await FirebaseStorage.instance.ref(storagePath).delete();
          } catch (_) {
            // ignora falha ao deletar arquivo individual
          }
        }
        // 2) Exclui do Firestore
        await FirebaseFirestore.instance.collection("materiais").doc(id).delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Material “$titulo” excluído.")),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao excluir material: $e")),
        );
      }
    }
  }

  Future<void> _abrirLink(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nenhum link disponível.")),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível abrir o link: $url")),
      );
    }
  }

  // Menu helper
  Widget _menuItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}

// Chip de info
class _ChipInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _ChipInfo({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
