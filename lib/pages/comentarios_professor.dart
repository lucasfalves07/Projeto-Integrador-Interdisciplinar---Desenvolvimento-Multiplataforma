import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComentariosProfessorPage extends StatefulWidget {
  const ComentariosProfessorPage({super.key});

  @override
  State<ComentariosProfessorPage> createState() =>
      _ComentariosProfessorPageState();
}

class _ComentariosProfessorPageState
    extends State<ComentariosProfessorPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _erro;

  List<String> _turmasProfessor = [];
  List<Map<String, dynamic>> _comentarios = [];

  String _filtroStatus = 'todos';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      setState(() {
        _loading = true;
        _erro = null;
      });

      final user = _auth.currentUser;
      if (user == null) throw "Professor não autenticado.";

      final turmasSnap = await _db
          .collection('turmas')
          .where('professorId', isEqualTo: user.uid)
          .get();

      final ids = turmasSnap.docs.map((t) => t.id).toList();
      _turmasProfessor = ids;

      await _buscarComentarios();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _buscarComentarios() async {
    if (_turmasProfessor.isEmpty) {
      setState(() {
        _comentarios = [];
        _loading = false;
      });
      return;
    }

    final List<Map<String, dynamic>> temp = [];
    final chunks = <List<String>>[];
    for (var i = 0; i < _turmasProfessor.length; i += 10) {
      chunks.add(_turmasProfessor.sublist(
          i,
          i + 10 > _turmasProfessor.length
              ? _turmasProfessor.length
              : i + 10));
    }

    for (final chunk in chunks) {
      final snap = await _db
          .collection('comentarios')
          .where('turmaId', whereIn: chunk)
          .get();
      temp.addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
    }

    temp.sort((a, b) {
      final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
      return tb.compareTo(ta);
    });

    if (!mounted) return;
    setState(() {
      _comentarios = temp;
      _loading = false;
    });
  }

  Future<void> _responderComentario(Map<String, dynamic> comentario) async {
    final controller =
        TextEditingController(text: comentario['respostaProfessor'] ?? '');

    final texto = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Responder comentário"),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: "Digite a resposta para o aluno...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Responder"),
          ),
        ],
      ),
    );

    if (texto == null || texto.isEmpty) return;

    try {
      final user = _auth.currentUser;
      final doc = _db.collection('comentarios').doc(comentario['id']);
      await doc.update({
        'respostaProfessor': texto,
        'respostaProfessorUid': user?.uid,
        'respostaEm': FieldValue.serverTimestamp(),
        'status': 'respondido',
      });
      await _buscarComentarios();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Resposta enviada ao aluno.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comentários dos alunos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!,
                  style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _buscarComentarios,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _filtros(),
                      const SizedBox(height: 12),
                      if (_comentariosFiltrados().isEmpty)
                        const Text("Nenhum comentário encontrado.",
                            style: TextStyle(color: Colors.black54))
                      else
                        ..._comentariosFiltrados().map(_comentarioCard),
                    ],
                  ),
                ),
    );
  }

  Widget _filtros() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _filtroStatus,
            decoration: const InputDecoration(
              labelText: "Status",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'todos', child: Text("Todos")),
              DropdownMenuItem(value: 'aberto', child: Text("Aberto")),
              DropdownMenuItem(
                  value: 'em_andamento', child: Text("Em andamento")),
              DropdownMenuItem(value: 'respondido', child: Text("Respondido")),
            ],
            onChanged: (v) => setState(() => _filtroStatus = v ?? 'todos'),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _comentariosFiltrados() {
    if (_filtroStatus == 'todos') return _comentarios;
    return _comentarios
        .where((c) => (c['status'] ?? 'aberto') == _filtroStatus)
        .toList();
  }

  Widget _comentarioCard(Map<String, dynamic> comentario) {
    final alunoNome = (comentario['alunoNome'] ?? '').toString();
    final alunoRa = (comentario['alunoRa'] ?? '').toString();
    final turmaNome = (comentario['turmaNome'] ?? '').toString();
    final atividade = (comentario['atividadeTitulo'] ?? '').toString();
    final mensagem = (comentario['mensagem'] ?? '').toString();
    final resposta = (comentario['respostaProfessor'] ?? '').toString();
    final status = (comentario['status'] ?? 'aberto').toString();
    final tipo = (comentario['tipo'] ?? 'comentario').toString();
    final criado = comentario['createdAt'];
    DateTime? dataEnvio;
    if (criado is Timestamp) dataEnvio = criado.toDate();

    Color statusColor;
    switch (status) {
      case 'respondido':
        statusColor = Colors.green;
        break;
      case 'em_andamento':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    alunoNome.isEmpty ? "Aluno" : alunoNome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'respondido'
                        ? "Respondido"
                        : status == 'em_andamento'
                            ? "Em andamento"
                            : "Aberto",
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text("RA: $alunoRa",
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text("Turma: $turmaNome",
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (atividade.isNotEmpty)
              Text("Atividade: $atividade",
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 12)),
            Text("Tipo: ${tipo.toUpperCase()}",
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (dataEnvio != null)
              Text(
                "Enviado em ${DateFormat('dd/MM/yyyy HH:mm').format(dataEnvio)}",
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            const SizedBox(height: 10),
            Text(mensagem),
            if (resposta.isNotEmpty) ...[
              const Divider(height: 20),
              Text("Resposta: $resposta",
                  style: const TextStyle(color: Colors.black87)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.reply),
                  label: Text(resposta.isNotEmpty ? "Atualizar resposta" : "Responder"),
                  onPressed: () => _responderComentario(comentario),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}