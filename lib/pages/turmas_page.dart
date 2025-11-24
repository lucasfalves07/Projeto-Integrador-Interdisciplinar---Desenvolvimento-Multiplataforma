// ---------------------------------------------------------------
// TURMAS PAGE — COMPLETAMENTE REVISADO PARA O SEU BANCO DE DADOS
// ---------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class TurmasPage extends StatefulWidget {
  const TurmasPage({super.key});

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _disciplinaController = TextEditingController();
  final TextEditingController _capacidadeController =
      TextEditingController(text: "30");
  final TextEditingController _periodoController =
      TextEditingController(text: DateTime.now().year.toString());

  String? _anoSelecionado;
  String? _turnoSelecionado;

  bool _carregando = false;

  final List<String> _anos = ["1º Ano", "2º Ano", "3º Ano"];
  final List<String> _turnos = ["Manhã", "Tarde", "Noite"];

  List<Map<String, dynamic>> _turmas = [];

  // ---------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  Future<void> _carregarTurmas() async {
    setState(() => _carregando = true);

    final user = _authService.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _turmas = [];
          _carregando = false;
        });
      }
      return;
    }

    try {
      final turmas = await _firestoreService.listarTurmasDoProfessor(user.uid);
      if (!mounted) return;
      setState(() {
        _turmas = turmas;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      _showError(e);
    }
  }

  // ---------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Minhas Turmas",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _carregarTurmas,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _mostrarDialogCriarTurma(context),
              icon: const Icon(Icons.add),
              label: const Text("Nova Turma"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _buscaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Buscar turmas...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _buildTurmasGrid(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // GRID DE TURMAS
  // ---------------------------------------------------------------
  Widget _buildTurmasGrid() {
    if (_turmas.isEmpty) {
      return const Center(child: Text("Nenhuma turma cadastrada."));
    }

    final query = _buscaController.text.trim().toLowerCase();

    final turmasFiltradas = _turmas.where((t) {
      final nome = (t['nome'] ?? '').toString().toLowerCase();
      return query.isEmpty || nome.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: turmasFiltradas.length,
        itemBuilder: (context, i) {
          final turma = turmasFiltradas[i];

          return _TurmaCard(
            id: turma['id'],
            data: turma,
            onEdit: () => _abrirGerenciarTurma(turma['id']),
            onDelete: () => _excluirTurma(turma['id'], turma['nome']),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // CRIAR NOVA TURMA
  // ---------------------------------------------------------------
  Future<void> _mostrarDialogCriarTurma(BuildContext context) async {
    _nomeController.clear();
    _disciplinaController.clear();
    _capacidadeController.text = "30";
    _periodoController.text = DateTime.now().year.toString();
    _anoSelecionado = null;
    _turnoSelecionado = null;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("Criar Nova Turma"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nomeController,
                    decoration:
                        const InputDecoration(labelText: "Nome da Turma"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _anoSelecionado,
                    items: _anos
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => _anoSelecionado = v),
                    decoration: const InputDecoration(labelText: "Ano/Série"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _turnoSelecionado,
                    items: _turnos
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setStateDialog(() => _turnoSelecionado = v),
                    decoration: const InputDecoration(labelText: "Turno"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _periodoController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Período Letivo"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _disciplinaController,
                    decoration: const InputDecoration(
                        labelText: "Disciplina Principal"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _capacidadeController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: "Capacidade"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00)),
                onPressed: () async {
                  final nome = _nomeController.text.trim();
                  final ano = _anoSelecionado;
                  final turno = _turnoSelecionado;
                  final periodoLetivo =
                      int.tryParse(_periodoController.text.trim());
                  final disciplinaNome = _disciplinaController.text.trim();
                  final cap =
                      int.tryParse(_capacidadeController.text.trim()) ?? 30;

                  if (nome.isEmpty ||
                      ano == null ||
                      turno == null ||
                      periodoLetivo == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Preencha todos os campos obrigatórios."),
                      ),
                    );
                    return;
                  }

                  final user =
                      _authService.currentUser ?? FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  try {
                    await _firestoreService.criarTurma(
                      nome: nome,
                      disciplina:
                          disciplinaNome.isEmpty ? "Disciplina" : disciplinaNome,
                      professorId: user.uid,
                      anoSerie: ano,
                      turno: turno,
                      periodoLetivo: periodoLetivo,
                      capacidade: cap,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      _carregarTurmas();
                    }
                  } catch (e) {
                    _showError(e);
                  }
                },
                child: const Text("Criar"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // REMOVER ALUNO DA TURMA
  // ---------------------------------------------------------------
  Future<void> _removerAluno(String turmaId, String ra) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection("turmas").doc(turmaId);
      final doc = await ref.get();
      final data = doc.data() ?? {};

      final alunosIds = (data["alunosIds"] as List?) ?? [];

      alunosIds.remove(ra);

      await ref.update({
        "alunosIds": alunosIds,
      });
    } catch (e) {
      _showError(e);
    }
  }

  // ---------------------------------------------------------------
  // ABRIR GERENCIAMENTO DA TURMA
  // ---------------------------------------------------------------
  Future<void> _abrirGerenciarTurma(String turmaId) async {
    await showDialog(
      context: context,
      builder: (_) => StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("turmas")
            .doc(turmaId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const AlertDialog(
                content: Center(child: CircularProgressIndicator()));
          }

          final turma = snap.data!.data() as Map<String, dynamic>? ?? {};
          final alunosIds =
              (turma["alunosIds"] as List?)?.cast<String>() ?? [];

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // HEADER
                    Row(
                      children: [
                        Text(
                          turma["nome"] ?? "Turma",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),

                    // BUTTONS
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _dialogAdicionarAluno(turmaId),
                          icon: const Icon(Icons.add),
                          label: const Text("Adicionar Aluno"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8A00),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // LISTA DE ALUNOS
                    Expanded(
                      child: alunosIds.isEmpty
                          ? const Center(
                              child: Text("Nenhum aluno nesta turma."),
                            )
                          : FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection("alunos")
                                  .where("ra",
                                      whereIn: alunosIds.isEmpty
                                          ? [" "]
                                          : alunosIds)
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final alunos = snapshot.data!.docs;

                                return ListView.separated(
                                  itemCount: alunos.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final a = alunos[i].data()
                                        as Map<String, dynamic>;

                                    return ListTile(
                                      title: Text(a["nome"] ?? "-"),
                                      subtitle: Text("RA: ${a["ra"] ?? "-"}"),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _removerAluno(turmaId, a["ra"]),
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
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------
  // ADICIONAR ALUNO
  // ---------------------------------------------------------------
  Future<void> _dialogAdicionarAluno(String turmaId) async {
    final nomeCtrl = TextEditingController();
    final raCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Adicionar Aluno"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: "Nome")),
            TextField(
                controller: raCtrl,
                decoration: const InputDecoration(labelText: "RA")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00)),
            onPressed: () async {
              final nome = nomeCtrl.text.trim();
              final ra = raCtrl.text.trim();

              if (nome.isEmpty || ra.isEmpty) return;

              final turmaRef = FirebaseFirestore.instance
                  .collection("turmas")
                  .doc(turmaId);

              // Adiciona no campo alunosIds da turma
              await turmaRef.update({
                "alunosIds": FieldValue.arrayUnion([ra]),
              });

              // Atualiza/Cria o aluno na coleção 'alunos'
              await FirebaseFirestore.instance
                  .collection("alunos")
                  .doc(ra)
                  .set({
                "id": ra,
                "nome": nome,
                "ra": ra,
                "status": "Ativo",
                "turmaId": turmaId,
                "disciplines": [],
                "criadoEm": FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // EXCLUIR TURMA
  // ---------------------------------------------------------------
  Future<void> _excluirTurma(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir Turma"),
        content: Text("Deseja excluir a turma '$nome'?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection("turmas").doc(id).delete();
      _carregarTurmas();
    } catch (e) {
      _showError(e);
    }
  }

  // ---------------------------------------------------------------
  // ERRO
  // ---------------------------------------------------------------
  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro: $e")),
    );
  }
}

// ---------------------------------------------------------------
// CARD REPRESENTANDO UMA TURMA
// ---------------------------------------------------------------
class _TurmaCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TurmaCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nome = data["nome"] ?? "Turma";
    final turno = data["turno"] ?? "-";
    final ano = data["anoSerie"] ?? "-";
    final qtdAlunos = ((data["alunosIds"] as List?) ?? []).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text("$ano • $turno",
                style: const TextStyle(color: Color(0xFF64748B))),
            const Spacer(),
            Text("$qtdAlunos alunos",
                style: const TextStyle(color: Color(0xFF64748B))),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFFFF8A00)),
                    onPressed: onEdit),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }
}