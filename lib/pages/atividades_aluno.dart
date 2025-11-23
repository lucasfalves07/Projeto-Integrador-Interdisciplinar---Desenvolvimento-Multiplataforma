// ===============================================================
// ATIVIDADES DO ALUNO — VERSÃO FINAL COMPLETA E SINCRONIZADA
// ===============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'atividade_detalhe.dart';

class AtividadesAlunoPage extends StatefulWidget {
  const AtividadesAlunoPage({super.key});

  @override
  State<AtividadesAlunoPage> createState() => _AtividadesAlunoPageState();
}

class _AtividadesAlunoPageState extends State<AtividadesAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _loading = true;

  late String _ra;
  List<String> _turmas = [];

  List<Map<String, dynamic>> _atividades = [];
  Map<String, Map<String, dynamic>> _entregas = {};

  Map<String, String> _mapDisciplinas = {};
  Map<String, String> _mapTurmas = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // ===============================================================
  // BUSCAR: RA → TURMAS → DISCIPLINAS → ATIVIDADES → ENTREGAS
  // ===============================================================
  Future<void> _carregarDados() async {
    try {
      setState(() => _loading = true);

      final user = _auth.currentUser;
      if (user == null) throw ("Usuário não autenticado");

      // USERS
      final userDoc = await _db.collection("users").doc(user.uid).get();
      _ra = userDoc["ra"];
      _turmas = List<String>.from(userDoc["turmas"]);

      // TURMAS
      final turmasSnap = await _db
          .collection("turmas")
          .where(FieldPath.documentId, whereIn: _turmas)
          .get();

      for (var t in turmasSnap.docs) {
        _mapTurmas[t.id] = t.data()["nome"];
      }

      // DISCIPLINAS das turmas
      final discsSnap = await _db
          .collection("disciplinas")
          .where("turmaId", whereIn: _turmas)
          .get();

      for (var d in discsSnap.docs) {
        _mapDisciplinas[d.id] = d.data()["nome"];
      }

      // ATIVIDADES (consulta individual por turma para evitar índices compostos)
      if (_turmas.isNotEmpty) {
        final futures = _turmas.map(
          (tid) => _db
              .collection("atividades")
              .where("turmaId", isEqualTo: tid)
              .get(),
        );
        final results = await Future.wait(futures);
        _atividades = results
            .expand((snap) => snap.docs)
            .map((d) => {"id": d.id, ...d.data()})
            .toList()
          ..sort((a, b) =>
              (b["criadoEmMs"] ?? 0).compareTo(a["criadoEmMs"] ?? 0));
      } else {
        _atividades = [];
      }

      // ENTREGAS
      final entSnap = await _db
          .collection("entregas")
          .where("alunoRa", isEqualTo: _ra)
          .get();

      _entregas = {
        for (var e in entSnap.docs)
          e.data()["atividadeId"]: {"id": e.id, ...e.data()}
      };

      setState(() => _loading = false);
    } catch (e) {
      _snack("Erro: $e", erro: true);
      setState(() => _loading = false);
    }
  }

  // ===============================================================
  // ENVIAR ENTREGA
  // ===============================================================
  Future<void> _enviarEntrega(Map<String, dynamic> atv) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw "Não autenticado";

      final pick = await FilePicker.platform.pickFiles(withData: true);
      if (pick == null) return;

      final file = pick.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw "Erro ao ler arquivo";

      final finalName = "${atv['id']}_${file.name}";
      final path = "entregas/$_ra/$finalName";

      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes);

      final url = await ref.getDownloadURL();

      final dados = {
        "atividadeId": atv["id"],
        "turmaId": atv["turmaId"],
        "disciplinaId": atv["disciplinaId"],
        "professorId": atv["professorId"],
        "alunoRa": _ra,
        "alunoUid": uid,
        "fileName": file.name,
        "fileSize": file.size,
        "url": url,
        "path": path,
        "enviadaEm": FieldValue.serverTimestamp(),
      };

      await _db
          .collection("entregas")
          .doc("${atv['id']}_$_ra")
          .set(dados, SetOptions(merge: true));

      _snack("Entrega enviada com sucesso!");
      _carregarDados();
    } catch (e) {
      _snack("Erro ao enviar: $e", erro: true);
    }
  }

  // ===============================================================
  Future<void> _abrirURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ===============================================================
  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? Colors.red : Colors.green,
      ),
    );
  }

  // ===============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Minhas Atividades")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarDados,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _atividades.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _cardAtividade(_atividades[i]),
              ),
            ),
    );
  }

  // ===============================================================
  // CARD DA ATIVIDADE
  // ===============================================================
  Widget _cardAtividade(Map<String, dynamic> atv) {
    final entrega = _entregas[atv["id"]];
    final anexos = List<Map<String, dynamic>>.from(atv["anexos"] ?? []);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AtividadeDetalhePage(
                atividade: {
                  ...atv,
                  "disciplinaNome": _mapDisciplinas[atv["disciplinaId"]],
                  "turmaNome": _mapTurmas[atv["turmaId"]],
                },
                entrega: entrega,
                ra: _ra,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                atv["titulo"] ?? "Atividade",
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                _mapDisciplinas[atv["disciplinaId"]] ?? "",
                style: const TextStyle(color: Colors.black54),
              ),
              Text(
                "Turma: ${_mapTurmas[atv["turmaId"]] ?? ""}",
                style: const TextStyle(color: Colors.black54),
              ),
              Text("Bimestre: ${atv['bimestre'] ?? '-'}"),

              // Peso e Max (se existirem)
              if (atv["peso"] != null)
                Text("Peso: ${atv['peso']}", style: const TextStyle(color: Colors.black54)),
              if (atv["max"] != null)
                Text("Valor Máximo: ${atv['max']}", style: const TextStyle(color: Colors.black54)),

              const SizedBox(height: 12),

              // ANEXOS DO PROFESSOR
              if (anexos.isNotEmpty)
                const Text(
                  "Arquivos do professor:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

              ...anexos.map((a) {
                return InkWell(
                  onTap: () => _abrirURL(a["url"]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a["nome"],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // ENTREGA DO ALUNO
              entrega == null
                  ? FilledButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Enviar Entrega"),
                      onPressed: () => _enviarEntrega(atv),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 6),
                            Text("Entrega enviada"),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Text("Arquivo: ${entrega['fileName']}"),
                        Text(
                          entrega["enviadaEm"] is Timestamp
                              ? "Enviado em: ${_fmt.format(entrega["enviadaEm"].toDate())}"
                              : "",
                          style: const TextStyle(color: Colors.black54),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text("Abrir"),
                              onPressed: () => _abrirURL(entrega["url"]),
                            ),
                            const SizedBox(width: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text("Reenviar"),
                              onPressed: () => _enviarEntrega(atv),
                            ),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
