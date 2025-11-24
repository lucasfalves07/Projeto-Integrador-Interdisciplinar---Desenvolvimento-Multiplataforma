// ---------------------------------------------------------------
//  MENSAGENS DO ALUNO — VERSÃO FINAL, MODERNA E 100% CORRIGIDA
// ---------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MensagensAlunoPage extends StatefulWidget {
  const MensagensAlunoPage({super.key});

  @override
  State<MensagensAlunoPage> createState() => _MensagensAlunoPageState();
}

class _MensagensAlunoPageState extends State<MensagensAlunoPage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _fmt = DateFormat('dd/MM HH:mm');

  String alunoUid = "";
  String alunoRA = "";
  String alunoNome = "";
  List<String> turmasIds = [];
  Map<String, String> turmaNomes = {};

  bool _loading = true;
  String? _erro;
  bool _erroPermissao = false;

  late TabController _tabs;

  List<String> professoresIds = [];
  Map<String, String> professoresNomes = {};

  String? professorSelecionado;
  String? turmaSelecionada;

  final _msgPrivadaCtrl = TextEditingController();
  final _msgTurmaCtrl = TextEditingController();
  final Set<String> _threadsGarantidas = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _carregarAluno();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _msgPrivadaCtrl.dispose();
    _msgTurmaCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  Future<void> _carregarAluno() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw "Usuário não logado";

      alunoUid = uid;

      final userSnap = await _db.collection("users").doc(uid).get();
      if (!userSnap.exists) throw "Usuário não encontrado";

      alunoRA = (userSnap.data()?["ra"] ?? "").toString();
      alunoNome = (userSnap.data()?["nome"] ?? "").toString();

      final dynamic turmasCampo = userSnap.data()?["turmas"];
      final tmpTurmas = <String>[];
      if (turmasCampo is List) {
        tmpTurmas.addAll(
          turmasCampo.map((e) => e.toString()).where((e) => e.isNotEmpty),
        );
      } else if (turmasCampo is String && turmasCampo.isNotEmpty) {
        tmpTurmas.add(turmasCampo);
      }

      final fallbackTurma =
          (userSnap.data()?["turmaId"] ?? userSnap.data()?["turma"])
              ?.toString();
      if (fallbackTurma != null &&
          fallbackTurma.isNotEmpty &&
          !tmpTurmas.contains(fallbackTurma)) {
        tmpTurmas.add(fallbackTurma);
      }

      turmasIds = tmpTurmas;

      if (turmasIds.isNotEmpty) turmaSelecionada = turmasIds.first;

      for (final id in turmasIds) {
        try {
          final t = await _db.collection("turmas").doc(id).get();
          if (t.exists) {
            turmaNomes[id] = (t.data()?["nome"] ?? id).toString();
          }
        } catch (e) {
          debugPrint("Erro ao carregar turma $id: $e");
        }
      }

      await _carregarProfessores();

      _safeSetState(() => _loading = false);
    } on FirebaseException catch (e) {
      _safeSetState(() {
        _erroPermissao = e.code == "permission-denied";
        _erro = _erroPermissao
            ? "Sem permissão para carregar suas mensagens."
            : "Erro ao carregar: ${e.message ?? e.code}";
        _loading = false;
      });
    } catch (e) {
      _safeSetState(() {
        _erro = "Erro ao carregar: $e";
        _loading = false;
      });
    }
  }

  Future<void> _garantirThreadAluno(String profUid) async {
    if (alunoRA.isEmpty) return;

    final threadId = "${alunoRA}_$profUid";
    if (_threadsGarantidas.contains(threadId)) return;
    _threadsGarantidas.add(threadId);

    try {
      final ref = _db.collection("threads").doc(threadId);
      final snap = await ref.get();
      if (snap.exists) return;

      final turmaPadrao =
          turmaSelecionada ?? (turmasIds.isNotEmpty ? turmasIds.first : null);

      final participantes = <String>{
        profUid,
        alunoRA,
        if (alunoUid.isNotEmpty) alunoUid,
      }.toList();

      await ref.set({
        "id": threadId,
        "alunoRa": alunoRA,
        if (alunoUid.isNotEmpty) "alunoUid": alunoUid,
        "alunoNome": alunoNome,
        "professorUid": profUid,
        "professorId": profUid,
        "professorNome": professoresNomes[profUid] ?? "",
        "turmaId": turmaPadrao,
        "participantes": participantes,
        "lastMessage": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "aberto": true,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint(
        "Erro ao garantir thread $threadId: ${e.message ?? e.code}",
      );
      _threadsGarantidas.remove(threadId);
    } catch (e) {
      debugPrint("Erro ao garantir thread $threadId: $e");
      _threadsGarantidas.remove(threadId);
    }
  }

  // ============================================================
  Future<void> _carregarProfessores() async {
    final Set<String> ids = {};
    final Map<String, String> nomes = {};

    Future<void> addProfessor(String? id, {String? nome}) async {
      if (id == null || id.isEmpty) return;
      ids.add(id);
      if (nome != null && nome.trim().isNotEmpty) {
        nomes[id] = nome.trim();
        return;
      }
      if (!nomes.containsKey(id)) {
        final fetched = await _buscarNomeProfessor(id);
        if (fetched != null && fetched.isNotEmpty) {
          nomes[id] = fetched;
        }
      }
    }

    for (final turma in turmasIds) {
      try {
        final snap = await _db.collection("turmas").doc(turma).get();
        final data = snap.data();
        if (data == null) continue;
        await addProfessor(
          (data["professorId"] ?? "").toString(),
          nome: data["professorNome"]?.toString(),
        );
      } catch (e) {
        debugPrint("Erro ao carregar dados da turma $turma: $e");
      }
    }

    final threads = await _buscarThreadsDoAluno();

    for (final th in threads) {
      final participantes =
          (th["participantes"] as List?)?.map((e) => e.toString()).toList() ??
              [];
      participantes
          .removeWhere((p) => p == alunoRA || p == alunoUid || p.isEmpty);
      if (participantes.isEmpty) continue;
      await addProfessor(participantes.first);
    }

    _safeSetState(() {
      professoresIds = ids.toList();
      professoresNomes = nomes;

      if (professoresIds.isNotEmpty) {
        if (professorSelecionado == null ||
            !professoresIds.contains(professorSelecionado)) {
          professorSelecionado = professoresIds.first;
        }
      } else {
        professorSelecionado = null;
      }
    });

    final selecionado = professorSelecionado;
    if (selecionado != null) {
      _garantirThreadAluno(selecionado);
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _buscarThreadsDoAluno() async {
    final base = _db.collection("threads");
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> docs = {};

    Future<void> tentar(Query<Map<String, dynamic>> query,
        {bool tentarCorrigir = false}) async {
      try {
        final snap = await query.get();
        for (final doc in snap.docs) {
          docs[doc.id] = doc;
          if (tentarCorrigir) {
            await _corrigirParticipantes(doc.reference, doc.data());
          }
        }
      } on FirebaseException catch (e) {
        if (e.code == "permission-denied") return;
        rethrow;
      }
    }

    if (alunoUid.isNotEmpty) {
      await tentar(base.where("participantes", arrayContains: alunoUid));
    }

    if (docs.isEmpty && alunoUid.isNotEmpty) {
      await tentar(base.where("alunoUid", isEqualTo: alunoUid),
          tentarCorrigir: true);
    }

    if (docs.isEmpty && alunoRA.isNotEmpty) {
      await tentar(base.where("alunoRa", isEqualTo: alunoRA),
          tentarCorrigir: true);
      await tentar(base.where("participantes", arrayContains: alunoRA),
          tentarCorrigir: true);
    }

    return docs.values.toList();
  }

  Future<void> _corrigirParticipantes(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    final participantes = <String>{
      ...((data["participantes"] as List?) ?? [])
          .map((e) => e?.toString() ?? "")
          .where((e) => e.isNotEmpty),
    };

    bool mudou = false;

    if (alunoUid.isNotEmpty && !participantes.contains(alunoUid)) {
      participantes.add(alunoUid);
      mudou = true;
    }

    if (alunoRA.isNotEmpty && !participantes.contains(alunoRA)) {
      participantes.add(alunoRA);
      mudou = true;
    }

    final updates = <String, dynamic>{};

    if (mudou) {
      updates["participantes"] = participantes.toList();
    }

    if (alunoUid.isNotEmpty && data["alunoUid"] != alunoUid) {
      updates["alunoUid"] = alunoUid;
    }

    if (updates.isNotEmpty) {
      await ref.set(updates, SetOptions(merge: true));
    }
  }

  // ============================================================
  Future<void> _enviarPrivado() async {
    final texto = _msgPrivadaCtrl.text.trim();
    if (texto.isEmpty || professorSelecionado == null) return;

    final profUid = professorSelecionado!;
    final professorNome = professoresNomes[profUid] ?? "";
    final threadId = "${alunoRA}_$profUid";
    final turmaPadrao =
        turmaSelecionada ?? (turmasIds.isNotEmpty ? turmasIds.first : null);

    try {
      final ref = _db.collection("threads").doc(threadId);
      final snap = await ref.get();
      final data = snap.data();
      final turmaId = (data?["turmaId"] ?? turmaPadrao)?.toString();

      final participantes = <String>{
        profUid,
        alunoRA,
        if (alunoUid.isNotEmpty) alunoUid,
      }.toList();

      await ref.set({
        "id": threadId,
        "alunoRa": alunoRA,
        "alunoUid": alunoUid,
        "alunoNome": alunoNome,
        "professorUid": profUid,
        "professorId": profUid,
        "professorNome": professorNome,
        "participantes": participantes,
        "turmaId": turmaId,
        "lastMessage": texto,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": data?["createdAt"] ?? FieldValue.serverTimestamp(),
        "aberto": true,
      }, SetOptions(merge: true));

      await ref.collection("itens").add({
        "texto": texto,
        "fromUid": alunoUid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      _msgPrivadaCtrl.clear();
    } catch (e) {
      _erroSnack("Erro ao enviar: $e");
    }
  }

  // ============================================================
  Future<void> _enviarTurma() async {
    final texto = _msgTurmaCtrl.text.trim();
    if (texto.isEmpty || turmaSelecionada == null) return;

    try {
      await _db
          .collection("turmas")
          .doc(turmaSelecionada)
          .collection("mensagens")
          .add({
        "mensagem": texto,
        "autorUid": alunoUid,
        "alunoRa": alunoRA,
        "createdAt": FieldValue.serverTimestamp(),
      });

      _msgTurmaCtrl.clear();
    } catch (e) {
      _erroSnack("Erro ao enviar: $e");
    }
  }

  Future<String?> _buscarNomeProfessor(String profId) async {
    try {
      final usuario = await _db.collection("users").doc(profId).get();
      final data = usuario.data();
      if (data != null) {
        final nome = (data["nome"] ?? "").toString();
        if (nome.isNotEmpty) return nome;
      }

      final discSnap = await _db
          .collection("disciplinas")
          .where("professorId", isEqualTo: profId)
          .limit(1)
          .get();

      if (discSnap.docs.isNotEmpty) {
        final disc = discSnap.docs.first.data();
        final nome = (disc["professor"] ?? disc["nome"] ?? "").toString();
        if (nome.isNotEmpty) return nome;
      }
    } catch (_) {}
    return null;
  }

  // ============================================================
  String _fmtHora(dynamic ts) {
    if (ts is Timestamp) return _fmt.format(ts.toDate());
    return "";
  }

  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_erro != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Mensagens")),
        body: Center(
          child: Text(
            _erro!,
            style: TextStyle(
              color: _erroPermissao ? Colors.orange : Colors.red,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mensagens"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Turma"),
            Tab(text: "Professor"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _abaTurma(),
          _abaPrivado(),
        ],
      ),
    );
  }

  // ============================================================
  Widget _abaTurma() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value:
                turmasIds.contains(turmaSelecionada) ? turmaSelecionada : null,
            decoration: const InputDecoration(
              labelText: "Turma",
              border: OutlineInputBorder(),
            ),
            items: turmasIds
                .map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(turmaNomes[id] ?? id),
                    ))
                .toList(),
            onChanged: (v) => _safeSetState(() => turmaSelecionada = v),
          ),
        ),
        Expanded(
          child: turmaSelecionada == null
              ? const Center(child: Text("Nenhuma turma cadastrada."))
              : StreamBuilder(
                  stream: _db
                      .collection("turmas")
                      .doc(turmaSelecionada)
                      .collection("mensagens")
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (_, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data!.docs;

                    if (docs.isEmpty) {
                      return const Center(child: Text("Nenhuma mensagem."));
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final m = docs[i].data();

                        return _bubble(
                          texto: m["mensagem"],
                          hora: _fmtHora(m["createdAt"]),
                          alinhadoDireita: m["autorUid"] == alunoUid,
                        );
                      },
                    );
                  },
                ),
        ),
        _inputEnviar(
          controller: _msgTurmaCtrl,
          hint: "Mensagem para a turma...",
          onSend: _enviarTurma,
        ),
      ],
    );
  }

  // ============================================================
  Widget _abaPrivado() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: professoresIds.contains(professorSelecionado)
                ? professorSelecionado
                : null,
            decoration: const InputDecoration(
              labelText: "Professor",
              border: OutlineInputBorder(),
            ),
            items: professoresIds
                .map((id) => DropdownMenuItem(
                      value: id,
                      child: Text(professoresNomes[id] ?? "Professor"),
                    ))
                .toList(),
            onChanged: (v) {
              _safeSetState(() => professorSelecionado = v);
              if (v != null) _garantirThreadAluno(v);
            },
          ),
        ),
        Expanded(
          child: professorSelecionado == null
              ? const Center(child: Text("Nenhum professor encontrado."))
              : _listaPrivado(),
        ),
        _inputEnviar(
          controller: _msgPrivadaCtrl,
          hint: "Mensagem privada...",
          onSend: _enviarPrivado,
        ),
      ],
    );
  }

  // ============================================================
  Widget _listaPrivado() {
    final profId = professorSelecionado!;
    final threadId = "${alunoRA}_$profId";

    return FutureBuilder<void>(
      future: _garantirThreadAluno(profId),
      builder: (_, futureSnap) {
        if (futureSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection("threads")
              .doc(threadId)
              .collection("itens")
              .orderBy("createdAt")
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              final erro = snap.error.toString();
              final texto = erro.contains("permission-denied")
                  ? "Sem permissão para visualizar esta conversa."
                  : "Erro ao carregar conversa.";
              return Center(
                child: Text(
                  texto,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final msgs = snap.data!.docs;

            if (msgs.isEmpty) {
              return const Center(child: Text("Nenhuma conversa."));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i].data();

                return _bubble(
                  texto: m["texto"],
                  hora: _fmtHora(m["createdAt"]),
                  alinhadoDireita: m["fromUid"] == alunoUid,
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  Widget _bubble({
    required String texto,
    required String hora,
    required bool alinhadoDireita,
  }) {
    return Align(
      alignment: alinhadoDireita ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alinhadoDireita
              ? Colors.deepPurple.shade100
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: alinhadoDireita
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              texto,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              hora,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  Widget _inputEnviar({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onSend,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _erroSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }
}