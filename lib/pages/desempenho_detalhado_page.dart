// ===============================================================
// Desempenho Detalhado — versão sincronizada com SEU Firestore REAL
// ===============================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/charts/notas_histogram.dart';

class DesempenhoDetalhadoPage extends StatefulWidget {
  const DesempenhoDetalhadoPage({super.key});

  @override
  State<DesempenhoDetalhadoPage> createState() =>
      _DesempenhoDetalhadoPageState();
}

class _DesempenhoDetalhadoPageState extends State<DesempenhoDetalhadoPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  bool loading = true;

  List<Map<String, dynamic>> turmas = [];
  String? turmaSelecionada;

  double mediaGeral = 0;
  int totalAprovados = 0;
  int totalReprovados = 0;

  Map<String, int> _buckets = {
    '0-2': 0,
    '2-4': 0,
    '4-6': 0,
    '6-8': 0,
    '8-10': 0,
  };

  @override
  void initState() {
    super.initState();
    _carregarTurmas();
  }

  // ============================================================
  // 🔹 Carregar turmas associadas ao professor
  // ============================================================
  Future<void> _carregarTurmas() async {
    if (user == null) return;
    setState(() => loading = true);

    final snap = await FirebaseFirestore.instance
        .collection("turmas")
        .where("professorId", isEqualTo: user!.uid)
        .get();

    turmas = snap.docs.map((e) => {"id": e.id, ...e.data()}).toList();

    if (turmas.isNotEmpty) {
      turmaSelecionada = turmas.first["id"];
    }

    await _carregarResumo();
  }

  // ============================================================
  // 🔹 Carregar desempenho da turma
  // ============================================================
  Future<void> _carregarResumo() async {
    try {
      if (turmaSelecionada == null) {
        setState(() => loading = false);
        return;
      }

      setState(() => loading = true);

      final db = FirebaseFirestore.instance;

      // -----------------------------------------
      // 1. Pegar todas as atividades da turma
      // -----------------------------------------
      final atvSnap = await db
          .collection("atividades")
          .where("turmaId", isEqualTo: turmaSelecionada)
          .get();

      final atividadesIds = atvSnap.docs.map((d) => d.id).toList();

      if (atividadesIds.isEmpty) {
        setState(() {
          mediaGeral = 0;
          totalAprovados = 0;
          totalReprovados = 0;
          _buckets = {
            '0-2': 0,
            '2-4': 0,
            '4-6': 0,
            '6-8': 0,
            '8-10': 0,
          };
          loading = false;
        });
        return;
      }

      // -----------------------------------------
      // 2. Buscar notas relacionadas às atividades
      // -----------------------------------------
      List<QueryDocumentSnapshot<Map<String, dynamic>>> notasDocs = [];

      for (var i = 0; i < atividadesIds.length; i += 10) {
        final slice = atividadesIds.sublist(
            i, i + 10 > atividadesIds.length ? atividadesIds.length : i + 10);

        final snap = await db
            .collection("notas")
            .where("atividadeId", whereIn: slice)
            .get();

        notasDocs.addAll(snap.docs);
      }

      if (notasDocs.isEmpty) {
        setState(() {
          mediaGeral = 0;
          totalAprovados = 0;
          totalReprovados = 0;
          loading = false;
        });
        return;
      }

      // -----------------------------------------
      // 3. Agrupar notas por aluno
      // -----------------------------------------
      final Map<String, List<double>> notasPorAluno = {};

      for (final doc in notasDocs) {
        final d = doc.data();
        final ra = (d["alunoRa"] ?? d["alunoRA"] ?? "").toString();
        if (ra.isEmpty) continue;

        final nota = (d["nota"] ?? 0).toDouble();

        notasPorAluno.putIfAbsent(ra, () => []);
        notasPorAluno[ra]!.add(nota);
      }

      // -----------------------------------------
      // 4. Calcular médias por aluno
      // -----------------------------------------
      double soma = 0;
      int aprovados = 0;
      int reprovados = 0;

      final buckets = {
        '0-2': 0,
        '2-4': 0,
        '4-6': 0,
        '6-8': 0,
        '8-10': 0,
      };

      for (final notas in notasPorAluno.values) {
        if (notas.isEmpty) continue;

        final media = notas.reduce((a, b) => a + b) / notas.length;
        soma += media;

        if (media >= 7) {
          aprovados++;
        } else {
          reprovados++;
        }

        final m = media.clamp(0, 10);

        String key;
        if (m < 2) {
          key = '0-2';
        } else if (m < 4) {
          key = '2-4';
        } else if (m < 6) {
          key = '4-6';
        } else if (m < 8) {
          key = '6-8';
        } else {
          key = '8-10';
        }

        buckets[key] = (buckets[key] ?? 0) + 1;
      }

      setState(() {
        mediaGeral =
            notasPorAluno.isNotEmpty ? soma / notasPorAluno.length : 0.0;
        totalAprovados = aprovados;
        totalReprovados = reprovados;
        _buckets = buckets;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar desempenho: $e')),
        );
      }
    }
  }

  // ============================================================
  // 🔹 Interface
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Desempenho Geral"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarResumo,
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _conteudo(),
    );
  }

  Widget _conteudo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: turmaSelecionada,
                  decoration: const InputDecoration(
                    labelText: "Turma",
                    border: OutlineInputBorder(),
                  ),
                  items: turmas
                      .map(
                        (t) => DropdownMenuItem<String>(
                          value: t["id"],
                          child: Text(t["nome"] ?? t["id"]),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => turmaSelecionada = v);
                    _carregarResumo();
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _kpi("Média Geral",
                        mediaGeral.toStringAsFixed(1), Colors.orange),
                    _kpi("Aprovados", "$totalAprovados", Colors.green),
                    _kpi("Reprovados", "$totalReprovados", Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: NotasHistogram(
                    buckets: _buckets,
                    title: 'Distribuição de médias da turma',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 260,
                  child: _graficoResumo(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // 🔹 Componentes visuais
  // ============================================================
  Widget _kpi(String titulo, String valor, Color cor) {
    return Expanded(
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Text(titulo, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 5),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 22,
                  color: cor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _graficoResumo() {
    final total = totalAprovados + totalReprovados;

    if (total == 0) {
      return const Center(child: Text("Nenhum dado disponível."));
    }

    final aprovPercent = ((totalAprovados / total) * 100).toStringAsFixed(1);
    final reprovPercent = ((totalReprovados / total) * 100).toStringAsFixed(1);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Resumo de Desempenho da Turma",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _barra("Aprovados", totalAprovados, aprovPercent, Colors.green),
            _barra("Reprovados", totalReprovados, reprovPercent, Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _barra(String label, int valor, String percent, Color color) {
    final percentValue = (double.tryParse(percent) ?? 0) / 100;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 40,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 40,
              height: 150 * percentValue,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text("$valor alunos",
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text("$percent%",
            style: const TextStyle(color: Colors.black87, fontSize: 12)),
      ],
    );
  }
}
