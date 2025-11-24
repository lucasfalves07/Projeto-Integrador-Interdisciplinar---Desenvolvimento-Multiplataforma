import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poliedro_flutter/pages/atividade_entregas_page.dart';
import 'package:url_launcher/url_launcher.dart';

class AtividadeProfessorDetalhePage extends StatefulWidget {
  final Map<String, dynamic> atividade;

  const AtividadeProfessorDetalhePage({
    super.key,
    required this.atividade,
  });

  @override
  State<AtividadeProfessorDetalhePage> createState() =>
      _AtividadeProfessorDetalhePageState();
}

class _AtividadeProfessorDetalhePageState
    extends State<AtividadeProfessorDetalhePage> {
  final _db = FirebaseFirestore.instance;
  final _dateFmt = DateFormat("dd/MM/yyyy HH:mm");

  String? _turmaNome;
  String? _disciplinaNome;

  bool _carregandoInfo = true;
  bool _apagando = false;

  @override
  void initState() {
    super.initState();
    _carregarRotulos();
  }

  // ============================================================================
  // CARREGAR LABELS — 100% COMPATÍVEL COM O BANCO DA DUDA
  // ============================================================================
  Future<void> _carregarRotulos() async {
    final turmaId = widget.atividade["turmaId"];
    final discId = widget.atividade["disciplinaId"];
    final nomeDiscAtividade = widget.atividade["disciplinaNome"];

    String? turmaNome;
    String? disciplinaNome = nomeDiscAtividade;

    try {
      if (turmaId != null) {
        final tdoc = await _db.collection("turmas").doc(turmaId).get();
        turmaNome = tdoc.data()?["nome"];

        // Buscar disciplina dentro da turma
        final list = tdoc.data()?["disciplinas"];
        if (list is List) {
          for (var d in list) {
            if (d is Map && d["id"] == discId) {
              disciplinaNome = d["nome"];
            }
          }
        }
      }

      disciplinaNome ??= discId;

      if (mounted) {
        setState(() {
          _turmaNome = turmaNome;
          _disciplinaNome = disciplinaNome;
          _carregandoInfo = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _carregandoInfo = false);
    }
  }

  // ============================================================================
  Future<void> _abrirUrl(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ============================================================================
  Future<void> _abrirEntregas() async {
    final id = widget.atividade["id"]?.toString();
    if (id == null || id.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AtividadeEntregasPage(
          atividadeId: id,
          atividade: widget.atividade,
        ),
      ),
    );
  }

  // ============================================================================
  Future<void> _confirmarExclusao() async {
    final id = widget.atividade["id"]?.toString();
    if (id == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir atividade"),
        content: const Text(
            "Tem certeza que deseja excluir esta atividade? Não será possível desfazer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _apagando = true);

    try {
      await _db.collection("atividades").doc(id).delete();

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Atividade excluída.")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _apagando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao excluir atividade.")),
      );
    }
  }

  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final atv = widget.atividade;
    final anexos = List<Map<String, dynamic>>.from(atv["anexos"] ?? []);

    final criadoMs = atv["criadoEmMs"];
    String criadoTexto = "-";

    if (criadoMs is int) {
      criadoTexto =
          _dateFmt.format(DateTime.fromMillisecondsSinceEpoch(criadoMs));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(atv["titulo"] ?? "Atividade"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: "Ver entregas",
            onPressed: _abrirEntregas,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Excluir atividade",
            onPressed: _apagando ? null : _confirmarExclusao,
          ),
        ],
        bottom: _carregandoInfo
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            atv["descricao"] ?? "",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),

          _info("Turma", _turmaNome),
          _info("Disciplina", _disciplinaNome),
          _info("Bimestre", atv["bimestre"]),
          _info("Criado em", criadoTexto),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.list_alt),
            label: const Text("Ver entregas dos alunos"),
            onPressed: _abrirEntregas,
          ),

          const SizedBox(height: 30),

          if (anexos.isNotEmpty)
            const Text(
              "Anexos",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

          ...anexos.map((a) {
            return Card(
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(a["nome"] ?? "Arquivo"),
                subtitle: Text(a["contentType"] ?? ""),
                onTap: () => _abrirUrl(a["url"] ?? ""),
              ),
            );
          }),

          if (anexos.isEmpty)
            const Text(
              "Nenhum anexo enviado.",
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  Widget _info(String titulo, String? valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$titulo:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor ?? "-",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}