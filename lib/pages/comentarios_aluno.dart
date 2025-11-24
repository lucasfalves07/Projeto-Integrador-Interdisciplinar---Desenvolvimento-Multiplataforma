import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ComentariosAlunoPage extends StatefulWidget {
  const ComentariosAlunoPage({super.key});

  @override
  State<ComentariosAlunoPage> createState() => _ComentariosAlunoPageState();
}

class _ComentariosAlunoPageState extends State<ComentariosAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _carregando = true;
  String? _erro;

  String? _alunoUid;
  String? _alunoRA;
  String? _alunoNome;
  String? _turmaId;
  String? _turmaNome;

  List<Map<String, dynamic>> _atividades = [];
  List<Map<String, dynamic>> _comentarios = [];

  final _assuntoCtrl = TextEditingController();
  final _mensagemCtrl = TextEditingController();
  String _tipoSelecionado = 'duvida';
  String? _atividadeSelecionada;

  @override
  void initState() {
    super.initState();
    _carregarBase();
  }

  @override
  void dispose() {
    _assuntoCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarBase() async {
    try {
      setState(() {
        _carregando = true;
        _erro = null;
      });

      final user = _auth.currentUser;
      if (user == null) throw "Usuário não autenticado.";

      final userSnap = await _db.collection('users').doc(user.uid).get();
      if (!userSnap.exists) throw "Usuário não encontrado.";

      final data = userSnap.data()!;
      final turmas =
          (data['turmas'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (turmas.isEmpty) {
        throw "Nenhuma turma vinculada ao seu usuário.";
      }

      final turmaAtual = turmas.first;
      final turmaSnap = await _db.collection('turmas').doc(turmaAtual).get();

      final atvSnap = await _db
          .collection('atividades')
          .where('turmaId', isEqualTo: turmaAtual)
          .get();

      _alunoUid = user.uid;
      _alunoRA = (data['ra'] ?? '').toString();
      _alunoNome = (data['nome'] ?? '').toString();
      _turmaId = turmaAtual;
      _turmaNome = turmaSnap.data()?['nome'] ?? turmaAtual;
      _atividades =
          atvSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      await _carregarComentarios();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _carregarComentarios() async {
    final uid = _alunoUid;
    if (uid == null) return;

    final snap = await _db
        .collection('comentarios')
        .where('alunoUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    if (!mounted) return;
    setState(() {
      _comentarios =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _carregando = false;
    });
  }

  Future<void> _enviarComentario() async {
    if (_alunoUid == null || _turmaId == null) return;

    final assunto = _assuntoCtrl.text.trim();
    final mensagem = _mensagemCtrl.text.trim();
    if (mensagem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Digite sua mensagem.")),
      );
      return;
    }

    try {
      setState(() => _carregando = true);

      final atividade = _atividades
          .firstWhere((a) => a['id'] == _atividadeSelecionada, orElse: () => {});
      final atividadeTitulo = (atividade['titulo'] ?? '').toString();

      await _db.collection('comentarios').add({
        'alunoUid': _alunoUid,
        'alunoRa': _alunoRA,
        'alunoNome': _alunoNome,
        'turmaId': _turmaId,
        'turmaNome': _turmaNome,
        'tipo': _tipoSelecionado,
        'titulo': assunto.isEmpty ? null : assunto,
        'mensagem': mensagem,
        'atividadeId': _atividadeSelecionada,
        'atividadeTitulo':
            _atividadeSelecionada == null || _atividadeSelecionada!.isEmpty
                ? null
                : atividadeTitulo,
        'status': 'aberto',
        'createdAt': FieldValue.serverTimestamp(),
        'respostaProfessor': null,
        'respostaEm': null,
        'respostaProfessorUid': null,
      });

      _assuntoCtrl.clear();
      _mensagemCtrl.clear();
      _atividadeSelecionada = null;
      _tipoSelecionado = 'duvida';

      await _carregarComentarios();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Comentário enviado com sucesso!")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Comentários e Dúvidas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarBase,
          )
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _carregarComentarios,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _formulario(),
                      const SizedBox(height: 20),
                      const Text(
                        "Histórico",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_comentarios.isEmpty)
                        const Text("Você ainda não enviou comentários.",
                            style: TextStyle(color: Colors.black54))
                      else
                        ..._comentarios.map(_comentarioCard),
                    ],
                  ),
                ),
    );
  }

  Widget _formulario() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Novo comentário",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipoSelecionado,
              decoration: const InputDecoration(
                labelText: "Tipo",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'duvida', child: Text("Dúvida")),
                DropdownMenuItem(value: 'comentario', child: Text("Comentário")),
                DropdownMenuItem(value: 'elogio', child: Text("Elogio")),
                DropdownMenuItem(value: 'outro', child: Text("Outro")),
              ],
              onChanged: (v) => setState(() => _tipoSelecionado = v ?? 'duvida'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _atividadeSelecionada,
              decoration: const InputDecoration(
                labelText: "Atividade (opcional)",
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text("Sem atividade específica"),
                ),
                ..._atividades.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a['id']?.toString(),
                    child: Text(a['titulo']?.toString() ?? a['id']),
                  ),
                )
              ],
              onChanged: (v) => setState(() => _atividadeSelecionada = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _assuntoCtrl,
              decoration: const InputDecoration(
                labelText: "Assunto (opcional)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mensagemCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Mensagem",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _enviarComentario,
                icon: const Icon(Icons.send),
                label: const Text("Enviar comentário"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _comentarioCard(Map<String, dynamic> comentario) {
    final status = (comentario['status'] ?? 'aberto').toString();
    final titulo = (comentario['titulo'] ?? '').toString();
    final atividade = (comentario['atividadeTitulo'] ?? '').toString();
    final mensagem = (comentario['mensagem'] ?? '').toString();
    final resposta = (comentario['respostaProfessor'] ?? '').toString();
    final data = comentario['createdAt'];
    DateTime? dt;
    if (data is Timestamp) dt = data.toDate();

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
                    titulo.isEmpty ? "Comentário" : titulo,
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
            if (atividade.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text("Atividade: $atividade",
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
            if (dt != null) ...[
              const SizedBox(height: 4),
              Text(
                "Enviado em ${DateFormat('dd/MM/yyyy HH:mm').format(dt)}",
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            Text(mensagem),
            if (resposta.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: const [
                  Icon(Icons.reply, color: Colors.deepPurple, size: 18),
                  SizedBox(width: 6),
                  Text("Resposta do professor",
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Text(resposta),
            ],
          ],
        ),
      ),
    );
  }
}