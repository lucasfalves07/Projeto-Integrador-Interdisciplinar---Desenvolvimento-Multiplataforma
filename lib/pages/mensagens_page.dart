import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MensagensPage extends StatefulWidget {
  const MensagensPage({super.key});

  @override
  State<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends State<MensagensPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _mensagemController = TextEditingController();

  String? _modoEnvio; // turma ou aluno
  String? _turmaSelecionada;
  String? _alunoSelecionado;
  bool _isSending = false;

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mensagens"),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _buildEnviarMensagemBox(),
          const Divider(height: 1),
          Expanded(child: _buildChatStream()),
        ],
      ),
    );
  }

  // ==========================================================
  // Caixa de envio
  // ==========================================================
  Widget _buildEnviarMensagemBox() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 🔹 Tipo de envio
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _modoEnvio,
                  hint: const Text("Enviar para..."),
                  items: const [
                    DropdownMenuItem(value: "turma", child: Text("Turma")),
                    DropdownMenuItem(value: "aluno", child: Text("Aluno")),
                  ],
                  onChanged: (v) => setState(() {
                    _modoEnvio = v;
                    _turmaSelecionada = null;
                    _alunoSelecionado = null;
                  }),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_modoEnvio != null)
                Expanded(child: _buildDestinoSelector(_modoEnvio!)),
            ],
          ),
          const SizedBox(height: 8),

          // 🔹 Mensagem
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mensagemController,
                  decoration: InputDecoration(
                    hintText: "Digite sua mensagem...",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.blue),
                onPressed: _isSending ? null : _enviarMensagem,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // Selector de destino (turma / aluno)
  // ==========================================================
  Widget _buildDestinoSelector(String modo) {
    if (modo == "turma") {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("turmas")
            .where("professorId", isEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          final turmas = snap.data!.docs;
          return DropdownButtonFormField<String>(
            value: _turmaSelecionada,
            hint: const Text("Selecione a turma"),
            items: turmas
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text((t.data() as Map)["nome"] ?? "Turma"),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _turmaSelecionada = v),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
      );
    }

    // 🔹 modo aluno
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("alunos").snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final alunos = snap.data!.docs;
        return DropdownButtonFormField<String>(
          value: _alunoSelecionado,
          hint: const Text("Selecione o aluno"),
          items: alunos
              .map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text((a.data() as Map)["nome"] ?? "Aluno"),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _alunoSelecionado = v),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // Stream de mensagens
  // ==========================================================
  Widget _buildChatStream() {
    final uid = currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("mensagens")
          .where("remetenteUid", isEqualTo: uid)
          .orderBy("enviadaEm", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              "Nenhuma mensagem encontrada.",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final mensagens = snapshot.data!.docs;

        return ListView.builder(
          reverse: true,
          itemCount: mensagens.length,
          itemBuilder: (context, index) {
            final msg = mensagens[index].data() as Map<String, dynamic>;
            final isProfessor = msg["remetenteTipo"] == "professor";
            final texto = msg["mensagem"] ?? "";
            final enviadaEm = (msg["enviadaEm"] as Timestamp?)?.toDate();
            final hora = enviadaEm != null
                ? "${enviadaEm.hour.toString().padLeft(2, '0')}:${enviadaEm.minute.toString().padLeft(2, '0')}"
                : "";

            return Align(
              alignment:
                  isProfessor ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isProfessor ? Colors.blue.shade100 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(texto, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(hora,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // Envio de mensagens
  // ==========================================================
  Future<void> _enviarMensagem() async {
    final texto = _mensagemController.text.trim();

    if (texto.isEmpty || _modoEnvio == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preencha todos os campos.")),
        );
      }
      return;
    }

    if ((_modoEnvio == "turma" && _turmaSelecionada == null) ||
        (_modoEnvio == "aluno" && _alunoSelecionado == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Selecione o destino da mensagem.")),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance.collection("mensagens").add({
        "mensagem": texto,
        "professorId": currentUser?.uid,
        "turmaIds": _turmaSelecionada != null ? [_turmaSelecionada] : [],
        "alunoUids": _alunoSelecionado != null ? [_alunoSelecionado] : [],
        "remetenteUid": currentUser?.uid,
        "remetenteTipo": "professor",
        "enviadaEm": FieldValue.serverTimestamp(),
      });

      _mensagemController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mensagem enviada.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar mensagem: $e")),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
}
