// ============================================================================
// ATIVIDADE_ENTREGAS_PAGE.DART — VERSÃO FINAL COMPATÍVEL COM O BANCO DA DUDA
// Lista todas as entregas dos alunos de uma atividade
// Totalmente sincronizado com turmas → alunosIds (RA) → alunos → entregas
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AtividadeEntregasPage extends StatefulWidget {
  final String atividadeId;
  final Map<String, dynamic> atividade;

  const AtividadeEntregasPage({
    super.key,
    required this.atividadeId,
    required this.atividade,
  });

  @override
  State<AtividadeEntregasPage> createState() => _AtividadeEntregasPageState();
}

class _AtividadeEntregasPageState extends State<AtividadeEntregasPage> {
  final _db = FirebaseFirestore.instance;
  final _fmt = DateFormat("dd/MM/yyyy HH:mm");

  List<Map<String, dynamic>> alunos = [];
  Map<String, Map<String, dynamic>> entregas = {};

  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // ============================================================================
  // CARREGAR ALUNOS DA TURMA + ENTREGAS
  // ============================================================================
  Future<void> _carregar() async {
    try {
      final turmaId = widget.atividade["turmaId"];

      if (turmaId == null) {
        setState(() => carregando = false);
        return;
      }

      // -------------------------------------------------------------
      // 1️⃣ Buscar turma → alunosIds = lista de RA
      // -------------------------------------------------------------
      final turmaDoc = await _db.collection("turmas").doc(turmaId).get();
      final alunoRAs = List<String>.from(turmaDoc.data()?["alunosIds"] ?? []);

      alunos = [];

      // -------------------------------------------------------------
      // 2️⃣ Buscar alunos pela coleção "alunos" → campo RA
      // -------------------------------------------------------------
      if (alunoRAs.isNotEmpty) {
        final snapAlunos = await _db
            .collection("alunos")
            .where("ra", whereIn: alunoRAs)
            .get();

        alunos = snapAlunos.docs.map((d) {
          return {
            "id": d.id,
            ...d.data(),
          };
        }).toList();

        // Caso algum RA esteja na turma mas não exista na coleção "alunos"
        for (var ra in alunoRAs) {
          if (!alunos.any((a) => a["ra"] == ra)) {
            alunos.add({
              "id": ra,
              "ra": ra,
              "nome": "Aluno $ra",
            });
          }
        }
      }

      // Ordenar lista por nome
      alunos.sort((a, b) => (a["nome"] ?? "").compareTo(b["nome"] ?? ""));

      // -------------------------------------------------------------
      // 3️⃣ Buscando entregas
      // -------------------------------------------------------------
      final entSnap = await _db
          .collection("entregas")
          .where("atividadeId", isEqualTo: widget.atividadeId)
          .get();

      entregas = {
        for (var d in entSnap.docs)
          (d.data()["alunoRa"] ?? "").toString(): {
            "id": d.id,
            ...d.data(),
          }
      };
    } catch (e) {
      debugPrint("ERRO EM ENTREGAS PAGE: $e");
    }

    setState(() => carregando = false);
  }

  // ============================================================================
  Future<void> _abrirArquivo(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ============================================================================
  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final total = alunos.length;
    final enviados =
        alunos.where((a) => entregas.containsKey(a["ra"])).length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Entregas — ${widget.atividade['titulo']}"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================================
          // RESUMO
          // ==========================================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _boxResumo("Entregues", enviados, Colors.green),
              _boxResumo("Pendentes", total - enviados, Colors.red),
              _boxResumo("Total", total, Colors.blue),
            ],
          ),

          const SizedBox(height: 25),

          const Text(
            "Alunos",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          // ==========================================================
          // LISTA DE ALUNOS
          // ==========================================================
          ...alunos.map((a) {
            final entrega = entregas[a["ra"]];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      entrega != null ? Colors.green : Colors.red,
                  child: Icon(
                    entrega != null ? Icons.check : Icons.close,
                    color: Colors.white,
                  ),
                ),
                title: Text("${a["nome"]} (${a["ra"]})"),
                subtitle: entrega == null
                    ? const Text("Ainda não entregou")
                    : Text(
                        entrega["enviadaEm"] != null
                            ? "Enviado em: ${_fmt.format(entrega["enviadaEm"].toDate())}"
                            : "Arquivo enviado",
                      ),
                trailing: entrega == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () =>
                            _abrirArquivo(entrega["url"] ?? ""),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  Widget _boxResumo(String label, int valor, Color cor) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            "$valor",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: cor),
          ),
        ],
      ),
    );
  }
}
