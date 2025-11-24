// ================================================================
//  MENSAGENS_PAGE.DART — SISTEMA COMPLETO DE MENSAGENS
//  PROFESSOR ↔ TURMA
//  PROFESSOR ↔ ALUNO
//  ALUNO ↔ PROFESSOR
//
//  Estrutura no Firestore:
//
//  threads/{threadId}
//      alunoUid
//      professorUid
//      turmaId
//      lastMessage
//      updatedAt
//      participantes: [uid1, uid2]
//
//  threads/{threadId}/itens/{msgId}
//      texto
//      fromUid
//      createdAt
//
//  turmas/{id}/mensagens/{msgId}
//      autorUid
//      mensagem
//      createdAt
//
// ================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';

class MensagensPage extends StatefulWidget {
  const MensagensPage({super.key});

  @override
  State<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends State<MensagensPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _msgCtrl = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isProfessor = false;
  bool _sending = false;

  List<String> _turmasDoProfessor = [];
  final Map<String, String> _mapNomeTurmasProfessor = {};
  List<Map<String, dynamic>> _alunosDoProfessor = [];
  bool _carregandoAlunos = false;

  String? _modo; // "turma" | "aluno"
  String? _turmaSelecionada;

  String? _alunoSelecionadoRa;
  Map<String, dynamic>? _alunoSelecionadoDados;
  String? _raAtual;

  String? _threadId;

  @override
  void initState() {
    super.initState();
    _carregarUsuario();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // Carregar se usuário é professor ou aluno
  // ======================================================
  Future<void> _carregarUsuario() async {
    final uid = _auth.currentUser!.uid;

    final snap = await _db.collection("users").doc(uid).get();
    final data = snap.data() ?? {};
    final perfil = data["perfil"] ?? "";
    _raAtual = data["ra"]?.toString();

    _isProfessor = perfil == "professor";

    if (_isProfessor) {
      final turmas = await _firestoreService.listarTurmasDoProfessor(uid);
      _turmasDoProfessor = turmas.map((e) => e["id"].toString()).toList();
      _mapNomeTurmasProfessor
        ..clear()
        ..addEntries(turmas.map(
          (t) =>
              MapEntry(t["id"].toString(), (t["nome"] ?? t["id"]).toString()),
        ));
      await _carregarAlunosDoProfessor();
    }

    if (mounted) setState(() {});
  }

  Future<void> _carregarAlunosDoProfessor() async {
    if (_turmasDoProfessor.isEmpty) {
      if (mounted) {
        setState(() {
          _alunosDoProfessor = [];
          _carregandoAlunos = false;
        });
      }
      return;
    }

    setState(() => _carregandoAlunos = true);

    final alunos = <Map<String, dynamic>>[];
    final vistos = <String>{};

    try {
      for (final chunk in _chunkList(_turmasDoProfessor)) {
        final snap = await _db
            .collection("alunos")
            .where("turmaId", whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final ra = (data["ra"] ?? doc.id).toString();
          if (vistos.add(ra)) {
            alunos.add({"id": ra, ...data});
          }
        }
      }

      final ras = alunos
          .map((a) => a["id"]?.toString())
          .where((id) => id != null)
          .cast<String>()
          .toList();
      for (final chunkRa in _chunkList(ras)) {
        final snapUsers =
            await _db.collection("users").where("ra", whereIn: chunkRa).get();
        for (final doc in snapUsers.docs) {
          final ra = (doc.data()["ra"] ?? "").toString();
          final idx =
              alunos.indexWhere((element) => element["id"]?.toString() == ra);
          if (idx != -1) {
            alunos[idx]["uid"] = doc.id;
          }
        }
      }

      alunos.sort((a, b) =>
          (a["nome"] ?? "").toString().compareTo((b["nome"] ?? "").toString()));
    } catch (e) {
      debugPrint("Erro ao carregar alunos: $e");
    }

    if (mounted) {
      setState(() {
        _alunosDoProfessor = alunos;
        _carregandoAlunos = false;
      });
    }
  }

  // ======================================================
  //  BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Mensagens", style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          if (_isProfessor) _seletorDeEnvio(),
          Expanded(child: _modo == null ? _listaConversas() : _chatView()),
        ],
      ),
    );
  }

  // ======================================================
  //  SELETOR MODO (TURMA / ALUNO)
  // ======================================================
  Widget _seletorDeEnvio() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _modo,
              decoration: _decoration(),
              hint: const Text("Enviar para..."),
              items: const [
                DropdownMenuItem<String>(value: "turma", child: Text("Turma")),
                DropdownMenuItem<String>(value: "aluno", child: Text("Aluno")),
              ],
              onChanged: (v) {
                setState(() {
                  _modo = v;
                  _turmaSelecionada = null;
                  _alunoSelecionadoRa = null;
                  _alunoSelecionadoDados = null;
                  _threadId = null;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          if (_modo == "turma")
            Expanded(child: _dropdownTurma())
          else if (_modo == "aluno")
            Expanded(child: _dropdownAluno()),
        ],
      ),
    );
  }

  InputDecoration _decoration() => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );

  // ======================================================
  // DROPDOWN — TURMA
  // ======================================================
  Widget _dropdownTurma() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _turmaSelecionada,
      decoration: _decoration(),
      hint: const Text("Selecione a turma"),
      items: _turmasDoProfessor
          .map((id) => DropdownMenuItem<String>(
                value: id,
                child: Text(_mapNomeTurmasProfessor[id] ?? id),
              ))
          .toList(),
      onChanged: (v) => setState(() => _turmaSelecionada = v),
    );
  }

  // ======================================================
  // DROPDOWN — ALUNO
  // ======================================================
  Widget _dropdownAluno() {
    if (_turmasDoProfessor.isEmpty) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _decoration(),
        items: const <DropdownMenuItem<String>>[],
        hint: const Text("Nenhuma turma"),
        onChanged: null,
      );
    }

    if (_carregandoAlunos) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_alunosDoProfessor.isEmpty) {
      return DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _decoration(),
        items: const <DropdownMenuItem<String>>[],
        hint: const Text("Nenhum aluno encontrado"),
        onChanged: null,
      );
    }

    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _alunoSelecionadoRa,
      decoration: _decoration(),
      hint: const Text("Selecione o aluno"),
      items: _alunosDoProfessor.map((a) {
        final nome = a["nome"] ?? "Aluno";
        final ra = a["ra"] ?? "";
        return DropdownMenuItem<String>(
          value: a["id"],
          child: Text("$nome - RA $ra"),
        );
      }).toList(),
      onChanged: (v) {
        _selecionarAluno(v);
      },
    );
  }

  Future<void> _selecionarAluno(String? ra,
      {Map<String, dynamic>? dadosThread}) async {
    if (ra == null || ra.isEmpty) {
      if (mounted) {
        setState(() {
          _alunoSelecionadoRa = null;
          _alunoSelecionadoDados = null;
          _threadId = null;
        });
      }
      return;
    }

    final dados = dadosThread ??
        _alunosDoProfessor.firstWhere(
          (a) => a["id"] == ra,
          orElse: () => <String, dynamic>{"id": ra},
        );

    final profUid = _auth.currentUser!.uid;
    final threadId = "${ra}_$profUid";

    if (mounted) {
      setState(() {
        _modo = "aluno";
        _alunoSelecionadoRa = ra;
        _alunoSelecionadoDados = dados;
        _threadId = threadId;
      });
    }

    await _garantirThreadExistente(threadId, dados);
  }

  Future<void> _garantirThreadExistente(
      String threadId, Map<String, dynamic> dadosAluno) async {
    final ref = _db.collection("threads").doc(threadId);
    final atual = await ref.get();
    if (atual.exists) return;

    final alunoRa = (dadosAluno["id"] ?? _alunoSelecionadoRa ?? "").toString();
    if (alunoRa.isEmpty) return;

    String alunoNome = (dadosAluno["nome"] ?? "").toString();
    String? turmaId = dadosAluno["turmaId"]?.toString();
    String? alunoUid = dadosAluno["uid"]?.toString();

    if ((alunoNome.isEmpty || turmaId == null || alunoUid == null) &&
        _alunosDoProfessor.isNotEmpty) {
      final doCache = _alunosDoProfessor.firstWhere(
        (a) => a["id"]?.toString() == alunoRa,
        orElse: () => <String, dynamic>{},
      );
      if (alunoNome.isEmpty) alunoNome = (doCache["nome"] ?? "").toString();
      turmaId ??= doCache["turmaId"]?.toString();
      alunoUid ??= doCache["uid"]?.toString();
    }

    if (alunoUid == null) {
      final q = await _db
          .collection("users")
          .where("ra", isEqualTo: alunoRa)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        alunoUid = q.docs.first.id;
      }
    }

    final profUid = _auth.currentUser!.uid;
    final participantes = <String>{
      profUid,
      alunoRa,
      if (alunoUid != null) alunoUid,
    }.toList();

    await ref.set({
      "alunoRa": alunoRa,
      "alunoNome": alunoNome,
      if (alunoUid != null) "alunoUid": alunoUid,
      if (turmaId != null) "turmaId": turmaId,
      "professorUid": profUid,
      "participantes": participantes,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "lastMessage": "",
    }, SetOptions(merge: true));
  }

  // ======================================================
  // LISTA DE CONVERSAS (THREADS)
  // ======================================================
  Widget _listaConversas() {
    final uid = _auth.currentUser!.uid;

    final participante = _isProfessor ? uid : (_raAtual ?? uid);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection("threads")
          .where("participantes", arrayContains: participante)
          .orderBy("updatedAt", descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final threads = snap.data!.docs;

        if (threads.isEmpty) {
          return const Center(child: Text("Nenhuma conversa."));
        }

        return ListView.builder(
          itemCount: threads.length,
          itemBuilder: (_, i) {
            final t = threads[i];
            final d = t.data();

            final lastMsg = d["lastMessage"] ?? "";
            final hora = (d["updatedAt"] as Timestamp?)
                    ?.toDate()
                    .toString()
                    .substring(11, 16) ??
                "";
            final alunoLabel =
                d["alunoNome"] ?? d["alunoRa"] ?? d["alunoUid"] ?? "";

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(_isProfessor ? "Aluno: $alunoLabel" : "Professor"),
              subtitle: Text(lastMsg, maxLines: 1),
              trailing: Text(hora),
              onTap: () {
                final alunoRa = (d["alunoRa"] ?? d["alunoUid"])?.toString();
                if (alunoRa == null) return;
                _selecionarAluno(alunoRa, dadosThread: {
                  "id": alunoRa,
                  "nome": d["alunoNome"],
                  "turmaId": d["turmaId"],
                  "uid": d["alunoUid"],
                });
              },
            );
          },
        );
      },
    );
  }

  // ======================================================
  // CHAT VIEW (TURMA OU PRIVADO)
  // ======================================================
  Widget _chatView() {
    if (_modo == "turma") {
      final nomeTurma = _turmaSelecionada == null
          ? ""
          : _mapNomeTurmasProfessor[_turmaSelecionada] ?? _turmaSelecionada!;
      return Column(
        children: [
          _chatHeader(
            nomeTurma.isEmpty ? "Chat da Turma" : "Chat da Turma $nomeTurma",
          ),
          Expanded(child: _streamTurma()),
          _inputMensagem(_enviarMensagemTurma),
        ],
      );
    }

    final nomeAluno =
        (_alunoSelecionadoDados?["nome"] ?? _alunoSelecionadoRa ?? "Aluno")
            .toString();

    return Column(
      children: [
        _chatHeader("Chat com $nomeAluno"),
        Expanded(child: _streamThreadPrivada()),
        _inputMensagem(_enviarMensagemPrivada),
      ],
    );
  }

  Widget _chatHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      color: Colors.white,
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  // ======================================================
  // STREAM — MENSAGENS DA TURMA
  // ======================================================
  Widget _streamTurma() {
    if (_turmaSelecionada == null) {
      return const Center(child: Text("Selecione uma turma."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection("turmas")
          .doc(_turmaSelecionada)
          .collection("mensagens")
          .orderBy("createdAt")
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final msgs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final m = msgs[i].data() as Map<String, dynamic>;
            final texto = m["mensagem"];
            final eu = m["autorUid"] == _auth.currentUser!.uid;

            return _bubble(texto, eu);
          },
        );
      },
    );
  }

  // ======================================================
  // STREAM — MENSAGENS PRIVADAS
  // ======================================================
  Widget _streamThreadPrivada() {
    if (_threadId == null) {
      return const Center(child: Text("Nenhuma conversa selecionada"));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection("threads")
          .doc(_threadId)
          .collection("itens")
          .orderBy("createdAt")
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhuma mensagem ainda."));
        }
        final msgs = snap.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final m = msgs[i].data();
            final texto = m["texto"];
            final eu = m["fromUid"] == _auth.currentUser!.uid;

            return _bubble(texto, eu);
          },
        );
      },
    );
  }

  // ======================================================
  // BUBBLE
  // ======================================================
  Widget _bubble(String texto, bool meu) {
    return Align(
      alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: meu ? Colors.blue.shade100 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(texto),
      ),
    );
  }

  // ======================================================
  // INPUT MSG
  // ======================================================
  Widget _inputMensagem(Function enviar) {
    return SafeArea(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(
                hintText: "Digite uma mensagem...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: _sending
                ? const CircularProgressIndicator()
                : const Icon(Icons.send, color: Colors.blue),
            onPressed: () => enviar(),
          )
        ],
      ),
    );
  }

  // ======================================================
  // ENVIAR PARA TURMA
  // ======================================================
  Future<void> _enviarMensagemTurma() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty || _turmaSelecionada == null) return;

    setState(() => _sending = true);

    await _db
        .collection("turmas")
        .doc(_turmaSelecionada)
        .collection("mensagens")
        .add({
      "autorUid": _auth.currentUser!.uid,
      "mensagem": txt,
      "createdAt": FieldValue.serverTimestamp(),
    });

    _msgCtrl.clear();
    setState(() => _sending = false);
  }

  // ======================================================
  // ENVIAR PRIVADO
  // ======================================================
  Future<void> _enviarMensagemPrivada() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty || _alunoSelecionadoRa == null) return;

    setState(() => _sending = true);

    final profUid = _auth.currentUser!.uid;
    final alunoRa = _alunoSelecionadoRa!;
    final alunoInfo = _alunoSelecionadoDados ??
        _alunosDoProfessor.firstWhere(
          (a) => a["id"] == alunoRa,
          orElse: () => <String, dynamic>{"id": alunoRa},
        );
    final turmaId = alunoInfo["turmaId"];
    final alunoNome = alunoInfo["nome"] ?? "";
    String? alunoUid = alunoInfo["uid"] ?? alunoInfo["userUid"];

    final threadId = _threadId ?? "${alunoRa}_$profUid";
    _threadId = threadId;

    if (alunoUid == null) {
      final q = await _db
          .collection("users")
          .where("ra", isEqualTo: alunoRa)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) alunoUid = q.docs.first.id;
    }

    await _garantirThreadExistente(threadId, alunoInfo);

    final ref = _db.collection("threads").doc(threadId);

    final participantes = <String>{
      profUid,
      alunoRa,
      if (alunoUid != null) alunoUid,
    }.toList();

    final payload = <String, dynamic>{
      "alunoRa": alunoRa,
      "alunoNome": alunoNome,
      "turmaId": turmaId,
      if (alunoUid != null) "alunoUid": alunoUid,
      "professorUid": profUid,
      "participantes": participantes,
      "lastMessage": txt,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    await ref.set(payload, SetOptions(merge: true));

    await ref.collection("itens").add({
      "texto": txt,
      "fromUid": profUid,
      "createdAt": FieldValue.serverTimestamp(),
    });

    _msgCtrl.clear();
    setState(() => _sending = false);
  }

  List<List<String>> _chunkList(List<String> origem, [int tamanho = 10]) {
    final chunks = <List<String>>[];
    for (var i = 0; i < origem.length; i += tamanho) {
      chunks.add(origem.sublist(
          i, i + tamanho > origem.length ? origem.length : i + tamanho));
    }
    return chunks;
  }
}