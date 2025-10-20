// lib/pages/dashboard_aluno.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAlunoPage extends StatefulWidget {
  const DashboardAlunoPage({super.key});

  @override
  State<DashboardAlunoPage> createState() => _DashboardAlunoPageState();
}

class _DashboardAlunoPageState extends State<DashboardAlunoPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String alunoName = "Carregando...";
  String alunoRA = "";
  List<String> turmasAluno = [];

  List<Map<String, dynamic>> notas = [];
  List<Map<String, dynamic>> materiais = [];
  List<Map<String, dynamic>> atividades = [];
  List<Map<String, dynamic>> mensagens = [];

  int badgeTarefas = 0;
  int badgeInbox = 0;

  bool isLoading = true;
  int _bottomIndex = 0;

  final TextEditingController _respostaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    if (currentUser == null) return;

    try {
      final userData = await _firestoreService.getUserByUid(currentUser!.uid);
      alunoName = userData?["nome"] ?? "Aluno(a)";
      alunoRA = userData?["ra"] ?? "";
      turmasAluno = List<String>.from(userData?["turmas"] ?? []);

      // Notas do próprio aluno
      notas = await _firestoreService.buscarNotasAluno(currentUser!.uid);

      // Buscar atividades, materiais e mensagens das turmas do aluno
      for (var turmaId in turmasAluno) {
        final listaMateriais =
            await _firestoreService.listarMateriaisPorTurma(turmaId);
        materiais.addAll(listaMateriais);

        final listaAtividades =
            await _firestoreService.buscarAtividadesPorTurma(turmaId);
        atividades.addAll(listaAtividades);

        // Mensagens destinadas à turma OU diretamente ao aluno
        final mensagensQuery = await FirebaseFirestore.instance
            .collection("mensagens")
            .where("destinatario", whereIn: [turmaId, alunoRA])
            .orderBy("enviadaEm", descending: true)
            .limit(10)
            .get();

        mensagens.addAll(
          mensagensQuery.docs.map((e) => e.data() as Map<String, dynamic>),
        );
      }

      badgeTarefas = atividades.length;
      badgeInbox = mensagens.length;

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao carregar dados: $e")),
        );
      }
    }
  }

  num _mediaGeral() {
    if (notas.isEmpty) return 0;
    final total = notas
        .map((n) => (n["nota"] ?? 0) as num)
        .fold<num>(0, (a, b) => a + b);
    return total / notas.length;
  }

  void _go(String path) {
    if (!mounted) return;
    context.push(path);
  }

  // Envio de resposta para o professor
  Future<void> _enviarResposta(String destinatarioProfessor) async {
    final texto = _respostaController.text.trim();
    if (texto.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection("mensagens").add({
        "mensagem": texto,
        "destinatario": destinatarioProfessor,
        "alunoId": currentUser?.uid,
        "alunoRA": alunoRA,
        "enviadaEm": DateTime.now(),
        "dataFormatada": "${DateTime.now().day.toString().padLeft(2, '0')}/"
            "${DateTime.now().month.toString().padLeft(2, '0')}/"
            "${DateTime.now().year}",
      });

      _respostaController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mensagem enviada ao professor!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar mensagem: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // HEADER
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset("assets/poliedro-logo.png", height: 40),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Bem-vindo, $alunoName",
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "RA: $alunoRA • Portal do Aluno",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push('/configuracoes'),
                            icon: const Icon(Icons.settings, size: 18),
                            label: const Text("Configurações"),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) context.go('/login');
                            },
                            child: const Text("Sair"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // BODY
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Métricas rápidas
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          children: [
                            _metricCard(
                              title: 'Média Geral',
                              value: _mediaGeral().toStringAsFixed(1),
                              color: Colors.green,
                              icon: Icons.star,
                            ),
                            _metricCard(
                              title: 'Atividades Pendentes',
                              value: atividades.length.toString(),
                              color: Colors.orange,
                              icon: Icons.flag,
                            ),
                            _metricCard(
                              title: 'Mensagens Novas',
                              value: mensagens.length.toString(),
                              color: Colors.blue,
                              icon: Icons.message_outlined,
                            ),
                            _metricCard(
                              title: 'Presença',
                              value: '95%',
                              color: Colors.teal,
                              icon: Icons.check_circle_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Próximas Atividades
                        const Text(
                          "📚 Próximas Atividades",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        atividades.isEmpty
                            ? const Text("Nenhuma atividade pendente 🎉")
                            : Column(
                                children: atividades.map((a) {
                                  final titulo = a["titulo"] ?? "Atividade";
                                  final turma =
                                      a["turma"] ?? "Turma não informada";
                                  final prazo = a["prazo"] != null
                                      ? (a["prazo"] as Timestamp)
                                          .toDate()
                                          .toString()
                                          .substring(0, 10)
                                      : "—";

                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(
                                          Icons.assignment_outlined,
                                          color: Colors.orange),
                                      title: Text(titulo),
                                      subtitle:
                                          Text("Turma: $turma\nPrazo: $prazo"),
                                    ),
                                  );
                                }).toList(),
                              ),

                        const SizedBox(height: 20),
                        const Text(
                          "💬 Mensagens Recentes",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),

                        mensagens.isEmpty
                            ? const Text("Nenhuma mensagem recente 📭")
                            : Column(
                                children: mensagens.map((m) {
                                  final texto =
                                      m["mensagem"] ?? "Mensagem sem texto";
                                  final remetente = m["professorId"] != null
                                      ? "Professor"
                                      : "Sistema";
                                  final data = m["dataFormatada"] ?? "";

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(Icons.mail_outline,
                                          color: Colors.blue),
                                      title: Text(remetente),
                                      subtitle: Text(texto),
                                      trailing: Text(data,
                                          style:
                                              const TextStyle(fontSize: 12)),
                                      onTap: () =>
                                          _abrirDialogResposta(remetente),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _bottomIndex,
        onTap: (i) {
          setState(() => _bottomIndex = i);
          switch (i) {
            case 1:
              _go('/aluno/materiais');
              break;
            case 2:
              _go('/aluno/notas');
              break;
            case 3:
              _go('/aluno/mensagens');
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Painel',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.menu_book, count: materiais.length),
            label: 'Materiais',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.assignment, count: badgeTarefas),
            label: 'Atividades',
          ),
          BottomNavigationBarItem(
            icon: _badgeIcon(Icons.mail, count: badgeInbox),
            label: 'Mensagens',
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required Color color,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeIcon(IconData icon, {int count = 0}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _abrirDialogResposta(String professor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Responder para $professor"),
        content: TextField(
          controller: _respostaController,
          decoration:
              const InputDecoration(labelText: "Digite sua resposta..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
              onPressed: () {
                _enviarResposta(professor);
                Navigator.pop(context);
              },
              child: const Text("Enviar")),
        ],
      ),
    );
  }
}
