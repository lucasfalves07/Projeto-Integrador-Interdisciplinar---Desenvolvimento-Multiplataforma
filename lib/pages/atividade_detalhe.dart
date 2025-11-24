// ======================================================================
// 🔵 AtividadeDetalhePage — VERSÃO FINAL, SINCRONIZADA E COMPLETA
// ======================================================================

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AtividadeDetalhePage extends StatefulWidget {
  final Map<String, dynamic> atividade;
  final Map<String, dynamic>? entrega;
  final String ra;

  const AtividadeDetalhePage({
    super.key,
    required this.atividade,
    required this.entrega,
    required this.ra,
  });

  @override
  State<AtividadeDetalhePage> createState() => _AtividadeDetalhePageState();
}

class _AtividadeDetalhePageState extends State<AtividadeDetalhePage> {
  final _db = FirebaseFirestore.instance;
  final _fmtDate = DateFormat("dd/MM/yyyy HH:mm");

  bool _enviando = false;
  String? turmaNome;
  String? disciplinaNome;

  // ======================================================================
  // 🔹 Abrir link externo
  // ======================================================================
  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ======================================================================
  // 🔹 Buscar TURMA e DISCIPLINA — para exibir os nomes certos
  // ======================================================================
  @override
  void initState() {
    super.initState();
    _carregarRotulos();
  }

  Future<void> _carregarRotulos() async {
    try {
      final turmaId = widget.atividade["turmaId"];
      final discId = widget.atividade["disciplinaId"];

      if (turmaId != null) {
        final tdoc = await _db.collection("turmas").doc(turmaId).get();
        turmaNome = tdoc.data()?["nome"];

        final discs = tdoc.data()?["disciplinas"];
        if (discs is List) {
          for (var d in discs) {
            if (d["id"] == discId) disciplinaNome = d["nome"];
          }
        }
      }

      // fallback
      disciplinaNome ??= widget.atividade["disciplinaNome"] ?? "--";

      setState(() {});
    } catch (e) {
      setState(() {});
    }
  }

  // ======================================================================
  // 🔹 Enviar / Reenviar arquivo
  // ======================================================================
  Future<void> _enviarEntrega() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw "Usuário não autenticado.";

      final pick = await FilePicker.platform.pickFiles(withData: true);
      if (pick == null) return;

      setState(() => _enviando = true);

      final file = pick.files.first;
      if (file.bytes == null) throw "Erro ao carregar arquivo";

      if (file.bytes!.length > 20 * 1024 * 1024) {
        throw "Arquivo maior que 20MB!";
      }

      final nomeFinal = "${widget.atividade['id']}_${file.name}";
      final path = "entregas/${widget.ra}/$nomeFinal";

      UploadTask task = FirebaseStorage.instance.ref(path).putData(file.bytes!);

      await task;
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();

      final entrega = {
        "atividadeId": widget.atividade["id"],
        "disciplinaId": widget.atividade["disciplinaId"],
        "turmaId": widget.atividade["turmaId"],
        "professorId": widget.atividade["professorId"],
        "alunoUid": uid,
        "alunoRa": widget.ra,
        "fileName": file.name,
        "fileSize": file.size,
        "url": url,
        "path": path,
        "enviadaEm": FieldValue.serverTimestamp(),
      };

      await _db
          .collection("entregas")
          .doc("${widget.atividade['id']}_${widget.ra}")
          .set(entrega, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Entrega enviada com sucesso!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context); // fecha detalhe e recarrega
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao enviar arquivo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _enviando = false);
  }

  // ======================================================================
  @override
  Widget build(BuildContext context) {
    final atv = widget.atividade;
    final entrega = widget.entrega;

    final anexos = List<Map<String, dynamic>>.from(atv["anexos"] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhes da Atividade"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.6,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ======================================================================
          // 🔵 Título
          // ======================================================================
          Text(
            atv["titulo"] ?? "Atividade",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          // ======================================================================
          // 🔹 Informações gerais
          // ======================================================================
          _info("Disciplina", disciplinaNome ?? "--"),
          _info("Turma", turmaNome ?? "--"),
          if (atv["bimestre"] != null) _info("Bimestre", atv["bimestre"]),
          if (atv["peso"] != null) _info("Peso", atv["peso"].toString()),
          if (atv["max"] != null) _info("Valor Máximo", atv["max"].toString()),
          if ((atv["descricao"] ?? "").toString().isNotEmpty)
            _info("Descrição", atv["descricao"]),

          const SizedBox(height: 30),

          // ======================================================================
          // 🔵 Anexos do professor
          // ======================================================================
          const Text(
            "Materiais do Professor",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          anexos.isEmpty
              ? const Text(
                  "Nenhum arquivo anexado.",
                  style: TextStyle(color: Colors.black54),
                )
              : Column(
                  children: anexos.map((a) {
                    return ListTile(
                      leading: const Icon(Icons.attach_file),
                      title: Text(a["nome"]),
                      subtitle: Text(a["contentType"]),
                      onTap: () => _abrirUrl(a["url"]),
                    );
                  }).toList(),
                ),

          const SizedBox(height: 40),

          // ======================================================================
          // 🔵 Entrega do aluno
          // ======================================================================
          const Text(
            "Sua Entrega",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          entrega == null ? _btnEnviarEntrega() : _blocoEntrega(entrega),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ======================================================================
  // 🔹 UI helpers
  // ======================================================================

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              )),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _btnEnviarEntrega() {
    return FilledButton.icon(
      icon: const Icon(Icons.upload_file),
      label: const Text("Enviar Arquivo"),
      onPressed: _enviando ? null : _enviarEntrega,
    );
  }

  Widget _blocoEntrega(Map<String, dynamic> entrega) {
    String dataStr = "";
    if (entrega["enviadaEm"] is Timestamp) {
      dataStr = _fmtDate.format(entrega["enviadaEm"].toDate());
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 6),
            Text("Entrega realizada"),
          ]),
          const SizedBox(height: 12),

          Text("Arquivo: ${entrega['fileName']}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("Enviado em: $dataStr",
              style: const TextStyle(color: Colors.black54)),

          const SizedBox(height: 16),

          Row(
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text("Abrir"),
                onPressed: () => _abrirUrl(entrega["url"]),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Reenviar"),
                onPressed: _enviando ? null : _enviarEntrega,
              ),
            ],
          ),
        ],
      ),
    );
  }
}