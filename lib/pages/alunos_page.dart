import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      appBar: AppBar(
        title: const Text("Alunos"),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔎 Campo de busca
            TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: "Buscar aluno por nome ou RA...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 📋 Lista de alunos (Firestore)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("alunos")
                    .orderBy("nome")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhum aluno cadastrado ainda.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final alunos = snapshot.data!.docs.where((doc) {
                    final dados = doc.data() as Map<String, dynamic>;
                    final nome = dados["nome"]?.toString().toLowerCase() ?? "";
                    final ra = dados["ra"]?.toString().toLowerCase() ?? "";
                    final filtro = _buscaController.text.toLowerCase();
                    return nome.contains(filtro) || ra.contains(filtro);
                  }).toList();

                  if (alunos.isEmpty) {
                    return const Center(
                      child: Text(
                        "Nenhum aluno encontrado com esse filtro.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: alunos.length,
                    itemBuilder: (context, index) {
                      final aluno =
                          alunos[index].data() as Map<String, dynamic>;
                      final nome = aluno["nome"] ?? "Sem nome";
                      final ra = aluno["ra"] ?? "—";
                      final email = aluno["email"] ?? "Sem e-mail";

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text("RA: $ra\n$email"),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () {
                              _mostrarDetalhesAluno(context, aluno);
                            },
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
      ),
    );
  }

  // 📘 Mostra detalhes do aluno (popup)
  void _mostrarDetalhesAluno(
      BuildContext context, Map<String, dynamic> aluno) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(aluno["nome"] ?? "Detalhes do aluno"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("RA: ${aluno["ra"] ?? "—"}"),
              Text("E-mail: ${aluno["email"] ?? "—"}"),
              Text("Turma: ${aluno["turma"] ?? "—"}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }
}
