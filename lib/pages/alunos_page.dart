// lib/pages/alunos_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AlunosPage extends StatefulWidget {
  const AlunosPage({super.key});

  @override
  State<AlunosPage> createState() => _AlunosPageState();
}

class _AlunosPageState extends State<AlunosPage> {
  final TextEditingController _buscaController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          "Gerenciamento de Alunos",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _campoDeBusca(),
            const SizedBox(height: 16),
            Expanded(child: _listaDeAlunos()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔍 CAMPO DE BUSCA
  // ============================================================
  Widget _campoDeBusca() {
    return TextField(
      controller: _buscaController,
      decoration: InputDecoration(
        hintText: "Buscar aluno por nome ou RA...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ============================================================
  // 📌 LISTA DE ALUNOS
  // ============================================================
  Widget _listaDeAlunos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("alunos")
          .orderBy("nome")
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhum aluno cadastrado."));
        }

        final filtro = _buscaController.text.trim().toLowerCase();

        final docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final nome = data["nome"]?.toString().toLowerCase() ?? "";
          final ra = data["ra"]?.toString().toLowerCase() ?? "";

          return filtro.isEmpty ||
              nome.contains(filtro) ||
              ra.contains(filtro);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("Nenhum aluno encontrado."));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final alunoDoc = docs[i];
            final aluno = alunoDoc.data() as Map<String, dynamic>;

            final nome = aluno["nome"] ?? "Sem nome";
            final ra = aluno["ra"] ?? "---";
            final status = aluno["status"] ?? "Ativo";
            final turmaId = aluno["turmaId"];

            return FutureBuilder<DocumentSnapshot>(
              future: turmaId != null
                  ? FirebaseFirestore.instance
                      .collection("turmas")
                      .doc(turmaId)
                      .get()
                  : Future.value(null),
              builder: (context, turmaSnap) {
                String turmaNome = "—";

                if (turmaSnap.data?.data() != null) {
                  turmaNome = (turmaSnap.data!.data()
                      as Map<String, dynamic>)["nome"];
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child:
                          const Icon(Icons.person, color: Colors.deepOrange),
                    ),
                    title: Text(
                      nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      "RA: $ra\nTurma: $turmaNome\nStatus: $status",
                      style: const TextStyle(height: 1.4),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: Colors.orange),
                      onPressed: () =>
                          _detalhesDoAluno(context, alunoDoc),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 🔍 DETALHES DO ALUNO + NOTAS
  // ============================================================
  Future<void> _detalhesDoAluno(
      BuildContext context, DocumentSnapshot alunoDoc) async {
    final aluno = alunoDoc.data() as Map<String, dynamic>;
    final ra = aluno["ra"];

    final notasRef = FirebaseFirestore.instance
        .collection("notas")
        .where("alunoRa", isEqualTo: ra);

    showDialog(
      context: context,
      builder: (_) => StreamBuilder<QuerySnapshot>(
        stream: notasRef.snapshots(),
        builder: (context, snapNotas) {
          final notas = snapNotas.data?.docs ?? [];

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: Text(aluno["nome"]),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("RA: $ra"),
                  const SizedBox(height: 4),
                  Text("Status: ${aluno["status"] ?? "Ativo"}"),
                  const Divider(height: 20),

                  const Text(
                    "🧾 Notas Lançadas",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange),
                  ),
                  const SizedBox(height: 10),

                  if (notas.isEmpty)
                    const Text("Nenhuma nota registrada.")
                  else
                    ...notas.map((notaDoc) {
                      final nota = notaDoc.data() as Map<String, dynamic>;
                      final valor = nota["nota"] ?? "-";
                      final atividadeId = nota["atividadeId"];

                      final dataFormatada = nota["data"] is Timestamp
                          ? DateFormat("dd/MM/yyyy").format(
                              (nota["data"] as Timestamp).toDate())
                          : "—";

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection("atividades")
                            .doc(atividadeId)
                            .get(),
                        builder: (context, atvSnap) {
                          String titulo = "Atividade";

                          if (atvSnap.data?.data() != null) {
                            titulo = (atvSnap.data!.data()
                                as Map<String, dynamic>)["titulo"];
                          }

                          return ListTile(
                            dense: true,
                            title: Text(titulo),
                            subtitle:
                                Text("Nota: $valor • Data: $dataFormatada"),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fechar"),
              ),
              TextButton(
                onPressed: () async {
                  final novoStatus = aluno["status"] == "Ativo"
                      ? "Inativo"
                      : "Ativo";

                  await FirebaseFirestore.instance
                      .collection("alunos")
                      .doc(alunoDoc.id)
                      .update({"status": novoStatus});

                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  aluno["status"] == "Ativo"
                      ? "Desativar Aluno"
                      : "Reativar Aluno",
                  style: TextStyle(
                    color: aluno["status"] == "Ativo"
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}