// ============================================================================
//  MATERIAIS DO ALUNO — VERSÃO FINAL 100% SINCRONIZADA COM O PROFESSOR
//  Leitura da coleção global /materiais (modelo Google Classroom)
//  Filtragem por turma → disciplina → tópico
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MateriaisAlunoPage extends StatefulWidget {
  const MateriaisAlunoPage({super.key});

  @override
  State<MateriaisAlunoPage> createState() => _MateriaisAlunoPageState();
}

class _MateriaisAlunoPageState extends State<MateriaisAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;

  // BUSCA
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = "";

  // Turmas
  List<Map<String, dynamic>> _turmas = [];
  String? _turmaId;

  // Disciplinas
  List<Map<String, dynamic>> _disciplinas = [];
  String? _disciplinaId;

  // Tópicos
  List<Map<String, dynamic>> _topicos = [];
  String? _topicoId;

  // Materiais
  List<Map<String, dynamic>> _materiais = [];
  String? _erro;
  bool _erroPermissao = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosDoAluno();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================================
  // CARREGAR DADOS DO ALUNO
  // ============================================================================
  Future<void> _carregarDadosDoAluno() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _safeSetState(() {
      _loading = true;
      _erro = null;
      _erroPermissao = false;
      _turmas = [];
      _turmaId = null;
    });

    try {
      final userSnap = await _db.collection("users").doc(uid).get();
      final user = userSnap.data() ?? {};

      final turmasIds = <String>{};
      final turmasCampo = user["turmas"];
      if (turmasCampo is List) {
        turmasIds.addAll(
          turmasCampo
              .map((e) => e == null ? "" : e.toString())
              .where((e) => e.isNotEmpty),
        );
      } else if (turmasCampo is String && turmasCampo.isNotEmpty) {
        turmasIds.add(turmasCampo);
      }

      final fallback = (user["turmaId"] ?? user["turma"])?.toString();
      if (fallback != null && fallback.isNotEmpty) {
        turmasIds.add(fallback);
      }

      final turmas = <Map<String, dynamic>>[];
      for (final id in turmasIds) {
        if (id.isEmpty) continue;
        var nome = id;
        try {
          final snap = await _db.collection("turmas").doc(id).get();
          if (snap.exists) {
            nome = (snap.data()?["nome"] ?? id).toString();
          }
        } on FirebaseException catch (e) {
          if (e.code == "permission-denied") {
            _erroPermissao = true;
          } else {
            rethrow;
          }
        }
        turmas.add({"id": id, "nome": nome});
      }

      _safeSetState(() {
        _turmas = turmas;
        _turmaId = _turmas.isNotEmpty ? _turmas.first["id"] : null;
      });

      if (_turmaId != null) {
        await _carregarMateriais();
      } else {
        _safeSetState(() {
          _materiais = [];
          _disciplinas = [];
          _topicos = [];
        });
      }
    } on FirebaseException catch (e) {
      _safeSetState(() {
        _erroPermissao = e.code == "permission-denied";
        _erro = _erroPermissao
            ? "Sem permissão para carregar seus dados."
            : "Erro ao carregar dados (${e.message ?? e.code}).";
      });
    } catch (e) {
      _safeSetState(() {
        _erro = "Erro ao carregar dados: $e";
      });
    } finally {
      _safeSetState(() => _loading = false);
    }
  }

  // ============================================================================
  // CARREGAR MATERIAIS (COLEÇÃO GLOBAL)
  // ============================================================================
  Future<void> _carregarMateriais() async {
    if (_turmaId == null) {
      _safeSetState(() {
        _materiais = [];
        _disciplinas = [];
        _topicos = [];
        _disciplinaId = null;
        _topicoId = null;
      });
      return;
    }

    try {
      final snap = await _db
          .collection("materiais")
          .where("turmaId", isEqualTo: _turmaId)
          .get();

      final lista = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
      lista.sort((a, b) {
        return _parseDate(b["criadoEm"]).compareTo(_parseDate(a["criadoEm"]));
      });

      _safeSetState(() {
        _erro = null;
        _erroPermissao = false;
        _sincronizarFiltrosComMateriais(lista);
      });
    } on FirebaseException catch (e) {
      _safeSetState(() {
        _materiais = [];
        _disciplinas = [];
        _topicos = [];
        _disciplinaId = null;
        _topicoId = null;
        _erroPermissao = e.code == "permission-denied";
        _erro = _erroPermissao
            ? "Sem permissão para visualizar os materiais desta turma."
            : "Erro ao carregar materiais (${e.message ?? e.code}).";
      });
    } catch (e) {
      _safeSetState(() {
        _materiais = [];
        _disciplinas = [];
        _topicos = [];
        _disciplinaId = null;
        _topicoId = null;
        _erro = "Erro ao carregar materiais: $e";
      });
    }
  }

  void _sincronizarFiltrosComMateriais(
    List<Map<String, dynamic>> materiais,
  ) {
    final disciplinaMap = <String, Map<String, dynamic>>{};
    for (final mat in materiais) {
      final id = (mat["disciplinaId"] ?? "").toString();
      if (id.isEmpty || disciplinaMap.containsKey(id)) continue;
      disciplinaMap[id] = {
        "id": id,
        "nome": (mat["disciplinaNome"] ?? id).toString(),
      };
    }

    final disciplinasOrdenadas = disciplinaMap.values.toList()
      ..sort((a, b) => (a["nome"] ?? a["id"] ?? "")
          .toString()
          .toLowerCase()
          .compareTo((b["nome"] ?? b["id"] ?? "").toString().toLowerCase()));

    final novaDisciplinaId = disciplinasOrdenadas
            .any((d) => d["id"]?.toString() == _disciplinaId)
        ? _disciplinaId
        : (disciplinasOrdenadas.isNotEmpty
            ? disciplinasOrdenadas.first["id"]?.toString()
            : null);

    final topicos = _extrairTopicos(materiais, novaDisciplinaId);
    final novoTopicoId = topicos.any((t) => t["id"]?.toString() == _topicoId)
        ? _topicoId
        : (topicos.isNotEmpty ? topicos.first["id"]?.toString() : null);

    _materiais = materiais;
    _disciplinas = disciplinasOrdenadas;
    _disciplinaId = novaDisciplinaId;
    _topicos = topicos;
    _topicoId = novoTopicoId;
  }

  List<Map<String, dynamic>> _extrairTopicos(
    List<Map<String, dynamic>> materiais,
    String? disciplinaId,
  ) {
    final vistos = <String>{};
    final lista = <Map<String, dynamic>>[];

    for (final mat in materiais) {
      if (disciplinaId != null &&
          (mat["disciplinaId"] ?? "").toString() != disciplinaId) {
        continue;
      }
      final topId = (mat["topicoId"] ?? "").toString();
      if (topId.isEmpty || !vistos.add(topId)) continue;
      lista.add({
        "id": topId,
        "nome": (mat["topicoNome"] ?? topId).toString(),
      });
    }

    lista.sort((a, b) => (a["nome"] ?? a["id"] ?? "")
        .toString()
        .toLowerCase()
        .compareTo((b["nome"] ?? b["id"] ?? "").toString().toLowerCase()));
    return lista;
  }

  Future<void> _trocarTurma(String? novaTurma) async {
    if (novaTurma == null || novaTurma == _turmaId) return;
    _safeSetState(() {
      _turmaId = novaTurma;
      _disciplinaId = null;
      _topicoId = null;
      _loading = true;
    });
    await _carregarMateriais();
    _safeSetState(() => _loading = false);
  }

  void _trocarDisciplina(String? novaDisciplina) {
    _safeSetState(() {
      _disciplinaId = novaDisciplina;
      final novosTopicos = _extrairTopicos(_materiais, _disciplinaId);
      _topicos = novosTopicos;
      if (!_topicos.any((t) => t["id"]?.toString() == _topicoId)) {
        _topicoId =
            _topicos.isNotEmpty ? _topicos.first["id"]?.toString() : null;
      }
    });
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================================
  // FILTRAR MATERIAIS
  // ============================================================================
  List<Map<String, dynamic>> get _filtrados {
    final busca = _search.toLowerCase();

    return _materiais.where((m) {
      if (!_visivelParaAluno(m)) return false;

      // Busca texto
      if (busca.isNotEmpty &&
          !(m["titulo"] ?? "").toString().toLowerCase().contains(busca)) {
        return false;
      }

      // Filtra disciplina
      final disciplinaMaterial = (m["disciplinaId"] ?? "").toString();
      if (_disciplinaId != null && disciplinaMaterial != _disciplinaId) {
        return false;
      }

      // Filtra tópico
      final topicoMaterial = (m["topicoId"] ?? "").toString();
      if (_topicoId != null && topicoMaterial != _topicoId) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _visivelParaAluno(Map<String, dynamic> material) {
    final vis = material["visivelPara"];
    final turmaAtual = _turmaId;
    if (turmaAtual == null) return false;

    if (vis is List && vis.isNotEmpty) {
      final valores = vis
          .map((e) => e == null ? "" : e.toString())
          .where((v) => v.isNotEmpty)
          .toList();
      return valores.contains(turmaAtual);
    }

    if (vis is String && vis.isNotEmpty) {
      return vis == turmaAtual;
    }

    return material["turmaId"] == turmaAtual;
  }

  // ============================================================================
  // DETECTAR SE MATERIAL É NOVO
  // ============================================================================
  bool _isNovo(dynamic ts) {
    if (ts is! Timestamp) return false;
    return DateTime.now().difference(ts.toDate()).inDays <= 7;
  }

  // ============================================================================
  // TIPO DO MATERIAL (PDF, VIDEO, LINK)
  // ============================================================================
  String _tipo(String url) {
    url = url.toLowerCase();
    if (url.endsWith(".pdf")) return "pdf";
    if (url.contains("youtube") || url.endsWith(".mp4")) return "video";
    return "link";
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Materiais")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _erroPermissao
                          ? "${_erro!}\nEntre em contato com a coordenação para liberar o acesso."
                          : _erro!,
                      style: TextStyle(
                        color: _erroPermissao ? Colors.red : Colors.black87,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
          : _turmaId == null
              ? const Center(
                  child: Text("Nenhuma turma vinculada."),
                )
              : Column(
                  children: [
                    _filtros(),
                    _campoBusca(),
                    Expanded(child: _lista()),
                  ],
                ),
    );
  }

  // ============================================================================
  // FILTROS (TURMA / DISCIPLINA / TÓPICO)
  // ============================================================================
  Widget _filtros() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Turma
          DropdownButtonFormField<String>(
            value: _turmaId,
            decoration: const InputDecoration(labelText: "Turma"),
            items: _turmas
                .map(
                  (t) => DropdownMenuItem<String>(
                    value: (t["id"] ?? "").toString(),
                    child: Text(t["nome"]?.toString() ?? ""),
                  ),
                )
                .toList(),
            onChanged: (v) {
              _trocarTurma(v);
            },
          ),
          const SizedBox(height: 12),

          // Disciplina
          DropdownButtonFormField<String>(
            value: _disciplinaId,
            decoration: const InputDecoration(labelText: "Disciplina"),
            items: _disciplinas
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: (d["id"] ?? "").toString(),
                    child: Text(d["nome"]?.toString() ?? ""),
                  ),
                )
                .toList(),
            onChanged: (v) => _trocarDisciplina(v),
          ),
          const SizedBox(height: 12),

          // Tópico
          DropdownButtonFormField<String>(
            value: _topicoId,
            decoration: const InputDecoration(labelText: "Tópico"),
            items: _topicos
                .map(
                  (t) => DropdownMenuItem<String>(
                    value: (t["id"] ?? "").toString(),
                    child: Text(t["nome"]?.toString() ?? ""),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _topicoId = v),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CAMPO DE BUSCA
  // ============================================================================
  Widget _campoBusca() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: "Buscar materiais...",
          filled: true,
          fillColor: const Color(0xfff2f2f7),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ============================================================================
  // LISTA DE MATERIAIS
  // ============================================================================
  Widget _lista() {
    final lista = _filtrados;

    if (lista.isEmpty) {
      return const Center(
        child: Text(
          "Nenhum material encontrado.",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: lista.length,
      itemBuilder: (_, i) {
        final m = lista[i];
        final tipo = _tipo(m["url"]);
        final ts = m["criadoEm"];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Icon(
              tipo == "pdf"
                  ? Icons.picture_as_pdf
                  : tipo == "video"
                      ? Icons.videocam
                      : Icons.link,
              size: 32,
              color: Colors.deepPurple,
            ),
            title: Text(m["titulo"] ?? ""),
            subtitle: Text(m["disciplinaNome"] ?? ""),
            trailing: _isNovo(ts)
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("NOVO", style: TextStyle(color: Colors.white)),
                  )
                : null,
            onTap: () async {
              final uri = Uri.tryParse(m["url"]);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
      },
    );
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
}