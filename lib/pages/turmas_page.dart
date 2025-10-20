// lib/pages/turmas_page.dart
import 'dart:convert';
import 'dart:html' as html; // Flutter Web: upload/download CSV
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TurmasPage extends StatefulWidget {
  const TurmasPage({super.key});

  @override
  State<TurmasPage> createState() => _TurmasPageState();
}

class _TurmasPageState extends State<TurmasPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController _buscaController = TextEditingController();

  // Criação de turma
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _capacidadeController =
      TextEditingController(text: "30");
  String? _anoSelecionado;
  String? _turnoSelecionado;
  bool _isCreating = false;

  final List<String> _anos = const ["1º Ano", "2º Ano", "3º Ano"];
  final List<String> _turnos = const ["Manhã", "Tarde", "Noite"];

  // Alunos
  final TextEditingController _alunoNomeController = TextEditingController();
  final TextEditingController _alunoRaController = TextEditingController();

  // Disciplinas
  final TextEditingController _discNomeController = TextEditingController();
  final TextEditingController _discProfController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ignore: avoid_print
    print("✅ TURMAS PAGE CARREGADA ${DateTime.now()}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // evita o "back" automático do AppBar (que estava duplicando)
        automaticallyImplyLeading: false,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF334155)),
          tooltip: "Voltar",
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Text(
                "Minhas Turmas",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  "Gerencie suas turmas e alunos",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _mostrarDialogCriarTurma(context),
              icon: const Icon(Icons.add),
              label: const Text("Nova Turma"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1200;
                final cross = isWide ? 3 : 2;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("turmas")
                      .where("professorId", isEqualTo: currentUser?.uid)
                      .orderBy("criadoEm", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("Nenhuma turma cadastrada ainda."),
                      );
                    }

                    final query = _buscaController.text.trim().toLowerCase();
                    final turmas = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final nome =
                          (data["nome"] ?? "").toString().toLowerCase();
                      final turno =
                          (data["turno"] ?? "").toString().toLowerCase();
                      final ano =
                          (data["anoSerie"] ?? "").toString().toLowerCase();
                      return query.isEmpty ||
                          nome.contains(query) ||
                          turno.contains(query) ||
                          ano.contains(query);
                    }).toList();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisExtent: 200,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: turmas.length,
                        itemBuilder: (context, index) {
                          final doc = turmas[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _TurmaCard(
                            id: doc.id,
                            data: data,
                            onEdit: () => _abrirPopupGerenciarTurma(
                              doc.id,
                              data,
                            ),
                            onDelete: () => _confirmarExclusaoTurma(
                              context,
                              doc.id,
                              data["nome"] ?? "",
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------
  // Criar Nova Turma
  // ------------------------------
  Future<void> _mostrarDialogCriarTurma(BuildContext context) async {
    _nomeController.clear();
    _capacidadeController.text = "30";
    _anoSelecionado = null;
    _turnoSelecionado = null;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setS) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Criar Nova Turma",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nomeController,
                      decoration: InputDecoration(
                        labelText: "Nome da Turma *",
                        hintText: "Ex: 3º Ano A",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF8A00), width: 2),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _anoSelecionado,
                            items: _anos
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (v) => setS(() {
                              _anoSelecionado = v;
                            }),
                            decoration: InputDecoration(
                              labelText: "Ano/Série *",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _turnoSelecionado,
                            items: _turnos
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList(),
                            onChanged: (v) => setS(() {
                              _turnoSelecionado = v;
                            }),
                            decoration: InputDecoration(
                              labelText: "Turno *",
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _capacidadeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Capacidade",
                        hintText: "30",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCreating
                            ? null
                            : () async {
                                final nome = _nomeController.text.trim();
                                final ano = _anoSelecionado;
                                final turno = _turnoSelecionado;
                                final cap = int.tryParse(
                                        _capacidadeController.text.trim()) ??
                                    30;

                                if (nome.isEmpty ||
                                    ano == null ||
                                    turno == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Preencha os campos obrigatórios."),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _isCreating = true);
                                try {
                                  await FirebaseFirestore.instance
                                      .collection("turmas")
                                      .add({
                                    "nome": nome,
                                    "professorId": currentUser!.uid,
                                    "anoSerie": ano,
                                    "turno": turno,
                                    "capacidade": cap,
                                    "periodoLetivo":
                                        DateTime.now().year.toString(),
                                    "alunos": [],
                                    "disciplinas": [],
                                    "criadoEm": FieldValue.serverTimestamp(),
                                  });
                                  if (mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text("Erro ao criar turma: $e"),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isCreating = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Criar Turma",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ------------------------------
  // Popup principal (ao clicar no lápis)
  // ------------------------------
  Future<void> _abrirPopupGerenciarTurma(
    String turmaId,
    Map<String, dynamic> turma,
  ) async {
    await showDialog(
      context: context,
      builder: (_) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("turmas")
              .doc(turmaId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!.data() as Map<String, dynamic>? ?? {};
            final nome = data["nome"] ?? "Turma";
            final ano = data["anoSerie"] ?? "-";
            final turno = data["turno"] ?? "-";
            final capacidade = (data["capacidade"] ?? 0).toString();
            final periodoLetivo = data["periodoLetivo"]?.toString() ?? "-";
            final alunos = (data["alunos"] as List?)?.cast<Map>() ?? <Map>[];
            final disciplinas =
                (data["disciplinas"] as List?)?.cast<Map>() ?? <Map>[];

            final size = MediaQuery.of(context).size;
            final dialogHeight = (size.height * 0.8).clamp(520.0, 900.0);

            // controllers para edição da aba Informações
            final infoAno = TextEditingController(text: ano);
            final infoTurno = TextEditingController(text: turno);
            final infoPeriodo = TextEditingController(text: periodoLetivo);
            final infoCap = TextEditingController(text: capacidade);

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTabController(
                    length: 3,
                    child: SizedBox(
                      height: dialogHeight,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  nome,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon:
                                    const Icon(Icons.close, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const TabBar(
                              labelColor: Color(0xFF0F172A),
                              unselectedLabelColor: Color(0xFF64748B),
                              indicator: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)),
                              ),
                              tabs: [
                                Tab(text: "Alunos"),
                                Tab(text: "Disciplinas"),
                                Tab(text: "Informações"),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // ---------- ALUNOS ----------
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _dialogAdicionarAluno(turmaId),
                                          icon: const Icon(Icons.add),
                                          label:
                                              const Text("Adicionar Aluno"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFFF8A00),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _importarCsvAlunos(turmaId),
                                          icon: const Icon(Icons.upload),
                                          label: const Text("Importar CSV"),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            side: const BorderSide(
                                                color: Color(0xFFE2E8F0)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _exportarCsvAlunos(nome, alunos),
                                          icon: const Icon(Icons.download),
                                          label: const Text("Exportar Lista"),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            side: const BorderSide(
                                                color: Color(0xFFE2E8F0)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          "Dica: clique em “Vincular” no aluno para marcar disciplinas.",
                                          style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: _TabelaAlunos(
                                          alunos: alunos
                                              .map<Map<String, dynamic>>(
                                                (e) => Map<String, dynamic>.from(
                                                  e as Map,
                                                ),
                                              )
                                              .toList(),
                                          onRemover: (ra) =>
                                              _removerAluno(turmaId, ra),
                                          onVincular: (aluno) =>
                                              _abrirVinculoPorAluno(
                                            turmaId: turmaId,
                                            aluno: aluno,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // ---------- DISCIPLINAS ----------
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _dialogVincularDisciplina(turmaId),
                                      icon: const Icon(Icons.add),
                                      label: const Text("Vincular Disciplina"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF8A00),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection("disciplinas")
                                            .where("turmaId",
                                                isEqualTo: turmaId)
                                            .orderBy("criadoEm",
                                                descending: true)
                                            .snapshots(),
                                        builder: (context, s) {
                                          if (s.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }
                                          final docs = s.data?.docs ?? [];
                                          if (docs.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                  "Nenhuma disciplina vinculada."),
                                            );
                                          }
                                          return ListView.separated(
                                            itemCount: docs.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (context, i) {
                                              final d = docs[i].data()
                                                  as Map<String, dynamic>;
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                        0xFFE2E8F0),
                                                  ),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    d["nome"] ?? "-",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    "Prof. ${d["professor"] ?? "-"}",
                                                    style: const TextStyle(
                                                      color:
                                                          Color(0xFF64748B),
                                                    ),
                                                  ),
                                                  trailing: TextButton(
                                                    onPressed: () =>
                                                        _desvincularDisciplina(
                                                      turmaId,
                                                      {
                                                        "id": docs[i].id,
                                                        "nome":
                                                            d["nome"] ?? "-",
                                                        "professor":
                                                            d["professor"] ??
                                                                "-",
                                                      },
                                                    ),
                                                    child:
                                                        const Text("Desvincular"),
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

                                // ---------- INFORMAÇÕES (EDITÁVEL) ----------
                                SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _infoEditable(
                                                label: "Ano/Série",
                                                controller: infoAno,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _infoEditable(
                                                label: "Turno",
                                                controller: infoTurno,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _infoEditable(
                                                label: "Período Letivo",
                                                controller: infoPeriodo,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _infoEditable(
                                                label: "Capacidade",
                                                controller: infoCap,
                                                keyboardType:
                                                    TextInputType.number,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection("turmas")
                                                    .doc(turmaId)
                                                    .set({
                                                  "anoSerie":
                                                      infoAno.text.trim(),
                                                  "turno":
                                                      infoTurno.text.trim(),
                                                  "periodoLetivo": infoPeriodo
                                                      .text
                                                      .trim(),
                                                  "capacidade": int.tryParse(
                                                          infoCap.text
                                                              .trim()) ??
                                                      0,
                                                }, SetOptions(merge: true));
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            "Informações atualizadas.")),
                                                  );
                                                }
                                              } catch (e) {
                                                _showError(e);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFF8A00),
                                              foregroundColor: Colors.white,
                                            ),
                                            icon: const Icon(Icons.save),
                                            label:
                                                const Text("Salvar alterações"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Vincular disciplinas clicando no aluno (busca direto no Firestore) ---
  Future<void> _abrirVinculoPorAluno({
    required String turmaId,
    required Map<String, dynamic> aluno,
  }) async {
    final ra = (aluno["ra"] ?? "").toString();
    if (ra.isEmpty) return;

    try {
      // Disciplinas desta turma (sempre com ids válidos)
      final discsSnap = await FirebaseFirestore.instance
          .collection("disciplinas")
          .where("turmaId", isEqualTo: turmaId)
          .get();

      final itens = discsSnap.docs
          .map((d) => {
                "id": d.id,
                "nome": (d.data()["nome"] ?? "").toString(),
                "professor": (d.data()["professor"] ?? "").toString(),
              })
          .toList();

      if (itens.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Cadastre uma disciplina antes de vincular.")));
        }
        return;
      }

      // seleção atual do aluno (ids)
      final alunoDoc =
          await FirebaseFirestore.instance.collection("alunos").doc(ra).get();
      final idsMarcados =
          List<String>.from((alunoDoc.data() ?? const {})["disciplinas"] ?? []);

      final selecionados = <String>{...idsMarcados};

      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setS) {
            final scroll = ScrollController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text("Vincular: ${aluno["nome"] ?? ra}"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SizedBox(
                  width: 540,
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Marque as disciplinas para este aluno:"),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Scrollbar(
                          controller: scroll,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: scroll,
                            itemCount: itens.length,
                            itemBuilder: (context, i) {
                              final it = itens[i];
                              final id = it["id"]!;
                              final checado = selecionados.contains(id);
                              return CheckboxListTile(
                                title: Text(it["nome"]!),
                                subtitle: (it["professor"] as String).isEmpty
                                    ? null
                                    : Text("Prof. ${it["professor"]}"),
                                value: checado,
                                onChanged: (v) => setS(() {
                                  if (v == true) {
                                    selecionados.add(id);
                                  } else {
                                    selecionados.remove(id);
                                  }
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // nomes para UI
                    final nomesSelecionados = itens
                        .where((e) => selecionados.contains(e["id"]))
                        .map((e) => e["nome"] as String)
                        .toList();

                    await _salvarVinculosDeAluno(
                      turmaId: turmaId,
                      ra: ra,
                      disciplinaIdsValidas: selecionados.toList(),
                      nomesSelecionados: nomesSelecionados,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Salvar"),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  // Salva IDs válidos no aluno + sincroniza coleções de disciplina + atualiza UI (nomes)
  Future<void> _salvarVinculosDeAluno({
    required String turmaId,
    required String ra,
    required List<String> disciplinaIdsValidas,
    required List<String> nomesSelecionados,
  }) async {
    final alunoRef = FirebaseFirestore.instance.collection("alunos").doc(ra);
    final turmaRef =
        FirebaseFirestore.instance.collection("turmas").doc(turmaId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        // Garante doc do aluno e atualiza os IDs
        final alunoSnap = await tx.get(alunoRef);
        if (!alunoSnap.exists) {
          tx.set(alunoRef, {
            "nome": alunoSnap.data()?["nome"],
            "turmaId": turmaId,
            "disciplinas": disciplinaIdsValidas,
          }, SetOptions(merge: true));
        } else {
          tx.update(alunoRef, {"disciplinas": disciplinaIdsValidas});
        }

        // Adiciona RA nas disciplinas selecionadas (com ID)
        if (disciplinaIdsValidas.isNotEmpty) {
          final sel = await FirebaseFirestore.instance
              .collection("disciplinas")
              .where(FieldPath.documentId, whereIn: disciplinaIdsValidas)
              .get();

          for (final doc in sel.docs) {
            final alunosIds = List<String>.from(doc.data()["alunos"] ?? []);
            if (!alunosIds.contains(ra)) {
              alunosIds.add(ra);
              tx.update(doc.reference, {"alunos": alunosIds});
            }
          }
        }

        // Remove RA das outras disciplinas da mesma turma que não foram selecionadas
        final todasDaTurma = await FirebaseFirestore.instance
            .collection("disciplinas")
            .where("turmaId", isEqualTo: turmaId)
            .get();

        for (final doc in todasDaTurma.docs) {
          if (!disciplinaIdsValidas.contains(doc.id)) {
            final alunosIds = List<String>.from(doc.data()["alunos"] ?? []);
            if (alunosIds.contains(ra)) {
              alunosIds.remove(ra);
              tx.update(doc.reference, {"alunos": alunosIds});
            }
          }
        }

        // Atualiza visualização da turma (chips por NOME)
        final turmaSnap = await tx.get(turmaRef);
        final turmaData = turmaSnap.data() ?? {};
        final alunos = (turmaData["alunos"] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];

        for (var i = 0; i < alunos.length; i++) {
          if ("${alunos[i]["ra"]}" == ra) {
            alunos[i]["disciplinas"] = nomesSelecionados;
            break;
          }
        }
        tx.update(turmaRef, {"alunos": alunos});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vínculos atualizados.")),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  // ------------------------------
  // Helpers — ALUNOS (adicionar/remover)
  // ------------------------------
  Future<void> _dialogAdicionarAluno(String turmaId) async {
    _alunoNomeController.clear();
    _alunoRaController.clear();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Adicionar Aluno"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              _alunoNomeController,
              "Nome do Aluno",
              "Ex: Ana Silva",
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _alunoRaController,
              "RA",
              "Ex: 2024001",
              keyboard: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = _alunoNomeController.text.trim();
              final ra = _alunoRaController.text.trim();
              if (nome.isEmpty || ra.isEmpty) return;

              try {
                final turmaRef = FirebaseFirestore.instance
                    .collection("turmas")
                    .doc(turmaId);

                final snap = await turmaRef.get();
                final data = snap.data() ?? {};
                final alunos =
                    (data["alunos"] as List?)?.cast<Map>() ?? <Map>[];

                final jaExiste =
                    alunos.any((a) => (a as Map)["ra"].toString() == ra);
                if (!jaExiste) {
                  alunos.add({
                    "nome": nome,
                    "ra": ra,
                    "status": "Ativo",
                    "disciplinas": <String>[],
                  });
                  await turmaRef.update({"alunos": alunos});
                }

                await FirebaseFirestore.instance
                    .collection("alunos")
                    .doc(ra)
                    .set({
                  "nome": nome,
                  "ra": ra,
                  "status": "Ativo",
                  "turmaId": turmaId,
                  "disciplinas": <String>[],
                }, SetOptions(merge: true));

                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError(e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
            ),
            child: const Text("Adicionar"),
          ),
        ],
      ),
    );
  }

  Future<void> _removerAluno(String turmaId, String ra) async {
    try {
      final ref =
          FirebaseFirestore.instance.collection("turmas").doc(turmaId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final alunos = (data["alunos"] as List?)?.cast<Map>() ?? <Map>[];
      final novo =
          alunos.where((a) => (a as Map)["ra"].toString() != ra).toList();
      await ref.update({"alunos": novo});

      await FirebaseFirestore.instance.collection("alunos").doc(ra).set({
        "turmaId": null,
      }, SetOptions(merge: true));
    } catch (e) {
      _showError(e);
    }
  }

  // ------------------------------
  // Importar e exportar CSV (Flutter Web)
  // ------------------------------
  Future<void> _importarCsvAlunos(String turmaId) async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Importação disponível apenas na Web.")),
      );
      return;
    }

    try {
      final uploadInput = html.FileUploadInputElement()..accept = '.csv';
      uploadInput.click();

      await uploadInput.onChange.first;
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader()..readAsText(file);
      await reader.onLoad.first;
      final text = reader.result as String;

      final lines = const LineSplitter().convert(text);
      final novos = <Map<String, dynamic>>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(",");
        if (parts.length < 2) continue;
        final ra = parts[0].trim();
        final nome = parts[1].trim();
        final status = (parts.length > 2 ? parts[2].trim() : "Ativo");
        novos.add({"ra": ra, "nome": nome, "status": status});
      }

      final ref = FirebaseFirestore.instance.collection("turmas").doc(turmaId);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final alunos = (data["alunos"] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      final setRAs = alunos.map((a) => (a["ra"] ?? "").toString()).toSet();

      for (final n in novos) {
        final ra = (n["ra"] ?? "").toString();
        if (!setRAs.contains(ra)) {
          alunos.add({
            "ra": ra,
            "nome": n["nome"],
            "status": n["status"],
            "disciplinas": <String>[],
          });
          await FirebaseFirestore.instance.collection("alunos").doc(ra).set({
            "nome": n["nome"],
            "ra": ra,
            "status": n["status"],
            "turmaId": turmaId,
            "disciplinas": <String>[],
          }, SetOptions(merge: true));
        }
      }

      await ref.update({"alunos": alunos});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alunos importados com sucesso.")),
        );
      }
    } catch (e) {
      _showError(e);
    }
  }

  void _exportarCsvAlunos(String nomeTurma, List alunos) {
    final rows = <List<String>>[];
    rows.add(["RA", "Nome", "Status", "Disciplinas"]);
    for (final a in alunos) {
      final m = Map<String, dynamic>.from(a as Map);
      rows.add([
        m["ra"]?.toString() ?? "",
        m["nome"]?.toString() ?? "",
        m["status"]?.toString() ?? "Ativo",
        (m["disciplinas"] is List)
            ? (m["disciplinas"] as List).join(" | ")
            : "",
      ]);
    }
    final csv = rows.map((r) => r.map(_escapeCsv).join(",")).join("\n");
    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes], "text/csv;charset=utf-8");
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = "alunos_${nomeTurma.replaceAll(' ', '_')}.csv"
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String _escapeCsv(String v) {
    final needQuotes = v.contains(",") || v.contains('"') || v.contains("\n");
    var out = v.replaceAll('"', '""');
    if (needQuotes) out = '"$out"';
    return out;
  }

  // ------------------------------
  // Helpers — DISCIPLINAS
  // ------------------------------
  Future<void> _dialogVincularDisciplina(String turmaId) async {
    _discNomeController.clear();
    _discProfController.clear();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Vincular Disciplina"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              _discNomeController,
              "Disciplina",
              "Ex: Matemática",
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _discProfController,
              "Professor(a)",
              "Ex: João Pereira",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = _discNomeController.text.trim();
              final prof = _discProfController.text.trim();
              if (nome.isEmpty || prof.isEmpty) return;

              try {
                final discRef = FirebaseFirestore.instance
                    .collection("disciplinas")
                    .doc();
                await discRef.set({
                  "nome": nome,
                  "professor": prof,
                  "professorId": currentUser?.uid,
                  "turmaId": turmaId,
                  "alunos": <String>[],
                  "criadoEm": FieldValue.serverTimestamp(),
                });

                // também salva um resumo dentro da turma para render rápido (opcional)
                await FirebaseFirestore.instance
                    .collection("turmas")
                    .doc(turmaId)
                    .set({
                  "disciplinas": FieldValue.arrayUnion([
                    {"id": discRef.id, "nome": nome, "professor": prof}
                  ])
                }, SetOptions(merge: true));

                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError(e);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
            ),
            child: const Text("Vincular"),
          ),
        ],
      ),
    );
  }

  Future<void> _desvincularDisciplina(
    String turmaId,
    Map<String, dynamic> disc,
  ) async {
    try {
      // remove do array da turma (resumo)
      await FirebaseFirestore.instance
          .collection("turmas")
          .doc(turmaId)
          .update({
        "disciplinas": FieldValue.arrayRemove([
          {
            "id": disc["id"],
            "nome": disc["nome"],
            "professor": disc["professor"]
          }
        ])
      });

      // limpa o turmaId no doc global (mantém a disciplina)
      if ((disc["id"] ?? "").toString().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection("disciplinas")
            .doc(disc["id"])
            .set({"turmaId": null}, SetOptions(merge: true));
      }
    } catch (e) {
      _showError(e);
    }
  }

  // ------------------------------
  // Excluir turma
  // ------------------------------
  Future<void> _confirmarExclusaoTurma(
    BuildContext context,
    String id,
    String nome,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir Turma"),
        content: Text("Deseja realmente excluir a turma “$nome”?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection("turmas").doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Turma “$nome” excluída.")),
          );
        }
      } catch (e) {
        _showError(e);
      }
    }
  }

  // ------------------------------
  // UI Helpers
  // ------------------------------
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _infoEditable({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: const InputDecoration(
          labelText: null,
          border: InputBorder.none,
        ).copyWith(labelText: label),
      ),
    );
  }

  Widget _infoLinha(
      String label1, String value1, String label2, String value2) {
    return Row(
      children: [
        Expanded(child: _infoBox(label1, value1)),
        const SizedBox(width: 12),
        Expanded(child: _infoBox(label2, value2)),
      ],
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(Object e) {
    final msg = e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg.contains('permission-denied')
              ? "Sem permissão no Firestore. Verifique as rules."
              : "Erro: $msg",
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// WIDGETS AUXILIARES
// -------------------------------------------------------------
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    nome,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Color(0xFFFF8A00)),
                  tooltip: "Gerenciar turma",
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Excluir turma",
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "$ano • $turno",
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabelaAlunos extends StatelessWidget {
  final List<Map<String, dynamic>> alunos;
  final Function(String ra) onRemover;
  final Function(Map<String, dynamic> aluno) onVincular;

  const _TabelaAlunos({
    required this.alunos,
    required this.onRemover,
    required this.onVincular,
  });

  @override
  Widget build(BuildContext context) {
    if (alunos.isEmpty) {
      return const Center(child: Text("Nenhum aluno adicionado ainda."));
    }

    return ListView.separated(
      itemCount: alunos.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final a = alunos[i];
        final discs = (a["disciplinas"] is List)
            ? (a["disciplinas"] as List).cast<String>()
            : const <String>[];
        return ListTile(
          title: Text(a["nome"]?.toString() ?? "-"),
          subtitle: Text(
            "RA: ${a["ra"] ?? "-"}"
            "${discs.isNotEmpty ? " • Disciplinas: ${discs.join(", ")}" : ""}",
          ),
          trailing: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () => onVincular(a),
                child: const Text("Vincular"),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => onRemover(a["ra"]?.toString() ?? ""),
                tooltip: "Remover aluno da turma",
              ),
            ],
          ),
        );
      },
    );
  }
}
