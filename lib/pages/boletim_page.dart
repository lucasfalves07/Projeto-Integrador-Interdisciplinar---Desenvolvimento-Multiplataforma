// ======================================================================
//  BOLETIM ESCOLAR — VERSÃO FINAL COMPLETA E CORRIGIDA
// ======================================================================
//  - Média correta por bimestre
//  - Média final correta
//  - Média geral correta (sem dividir por bimestre sem nota)
//  - Situação correta (Aprovado / Recuperação / Reprovado)
//  - Exibe atividades por bimestre
//  - Atualiza automaticamente
//  - Totalmente sincronizado com o painel do professor
//  - 100% compatível com o Firestore da Duda
// ======================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _ordemBimestres = [
  '1º Bimestre',
  '2º Bimestre',
  '3º Bimestre',
  '4º Bimestre'
];

class BoletimPage extends StatefulWidget {
  const BoletimPage({super.key});

  @override
  State<BoletimPage> createState() => _BoletimPageState();
}

class _BoletimPageState extends State<BoletimPage> {
  final _auth = FirebaseAuth.instance;

  String _alunoNome = '-';
  String _alunoRA = '-';
  String? _turmaId;
  String _turmaNome = '-';

  bool _carregando = true;

  // Dados
  Map<String, String> _disciplinasNomes = {};
  Map<String, Map<String, double>> _mediasPorDisciplina = {};
  Map<String, double> _mediaFinalPorDisciplina = {};
  Map<String, Map<String, List<Map<String, dynamic>>>> _atividadesAgrupadas = {};

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _carregarTudo());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ======================================================================
  //  CARREGAMENTO GERAL
  // ======================================================================

  Future<void> _carregarTudo() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final db = FirebaseFirestore.instance;

      // Carregar dados do aluno
      final userSnap = await db.collection("users").doc(uid).get();
      final usr = userSnap.data() ?? {};

      _alunoNome = usr["nome"] ?? "-";
      _alunoRA = usr["ra"] ?? "-";

      final turmas = (usr["turmas"] ?? []) as List;
      if (turmas.isEmpty) return;

      _turmaId = turmas.first;

      final turmaSnap = await db.collection("turmas").doc(_turmaId).get();
      _turmaNome = turmaSnap.data()?["nome"] ?? "-";

      // Carregar atividades
      final atividadesSnap = await db
          .collection("atividades")
          .where("turmaId", isEqualTo: _turmaId)
          .get();

      final atividades = {
        for (final d in atividadesSnap.docs) d.id: d.data(),
      };

      // Carregar notas
      final notasSnap = await db
          .collection("notas")
          .where("alunoRa", isEqualTo: _alunoRA)
          .where("turmaId", isEqualTo: _turmaId)
          .get();

      final Set<String> disciplinas = {};

      // Coletar disciplinas
      for (final atv in atividades.values) {
        disciplinas.add(atv["disciplinaId"]);
      }

      for (final n in notasSnap.docs) {
        final atv = atividades[n["atividadeId"]];
        if (atv != null) disciplinas.add(atv["disciplinaId"]);
      }

      // Carregar nomes das disciplinas
      _disciplinasNomes.clear();
      for (final id in disciplinas) {
        final d = await db.collection("disciplinas").doc(id).get();
        _disciplinasNomes[id] = d.data()?["nome"] ?? "Disciplina";
      }

      // Agrupar notas
      final acumuladores = <String, Map<String, _Acum>>{};
      _atividadesAgrupadas.clear();

      for (final n in notasSnap.docs) {
        final data = n.data();
        final atvId = data["atividadeId"];
        final atv = atividades[atvId];
        if (atv == null) continue;

        final disciplinaId = atv["disciplinaId"];

        final nota = (data["nota"] ?? 0).toDouble();
        final peso = (atv["peso"] ?? 1).toDouble();

        String bimestre = data["bimestre"] ?? "1º Bimestre";
        final nro = bimestre.replaceAll(RegExp(r'[^0-9]'), "");
        bimestre = "${nro}º Bimestre";

        acumuladores.putIfAbsent(disciplinaId, () => {});
        acumuladores[disciplinaId]!.putIfAbsent(bimestre, () => _Acum());
        acumuladores[disciplinaId]![bimestre]!.add(nota, peso);

        // Salvar atividade
        _atividadesAgrupadas.putIfAbsent(disciplinaId, () => {});
        _atividadesAgrupadas[disciplinaId]!.putIfAbsent(bimestre, () => []);
        _atividadesAgrupadas[disciplinaId]![bimestre]!.add({
          "titulo": atv["titulo"],
          "peso": peso,
          "nota": nota,
        });
      }

      // Calcular médias corretas
      _mediasPorDisciplina.clear();
      _mediaFinalPorDisciplina.clear();

      for (final disc in disciplinas) {
        _mediasPorDisciplina[disc] = {};
        double somaNotas = 0;
        int bimestresComNota = 0;

        for (final b in _ordemBimestres) {
          final ac = acumuladores[disc]?[b];
          double media = 0;

          if (ac != null && ac.peso > 0) {
            media = (ac.total / ac.peso);
            somaNotas += media;
            bimestresComNota++;
          }

          _mediasPorDisciplina[disc]![b] =
              double.parse(media.toStringAsFixed(1));
        }

        double mediaFinal = bimestresComNota == 0
            ? 0
            : somaNotas / bimestresComNota;

        _mediaFinalPorDisciplina[disc] =
            double.parse(mediaFinal.toStringAsFixed(1));
      }

      setState(() => _carregando = false);
    } catch (e) {
      debugPrint("ERRO NO BOLETIM: $e");
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ======================================================================
  // SITUAÇÃO
  // ======================================================================

  String _situacao(double m) {
    if (m >= 7) return "APROVADO";
    if (m >= 5) return "RECUPERAÇÃO";
    return "REPROVADO";
  }

  Color _corSituacao(double m) {
    if (m >= 7) return Colors.green;
    if (m >= 5) return Colors.orange;
    return Colors.red;
  }

  // ======================================================================
  // UI
  // ======================================================================

  @override
  Widget build(BuildContext context) {
    final double mediaGeral = _calcularMediaGeral();

    return Scaffold(
      backgroundColor: const Color(0xfff5f4fb),
      appBar: AppBar(
        title: const Text("Boletim Escolar"),
        backgroundColor: const Color(0xff6A5AE0),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(mediaGeral),
                const SizedBox(height: 20),
                _tabelaDisciplinas(),
              ],
            ),
    );
  }

  // HEADER
  Widget _header(double mediaGeral) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xff6A5AE0), Color(0xff8F79F3)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_alunoNome,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          Text("RA: $_alunoRA", style: const TextStyle(color: Colors.white70)),
          Text("Turma: $_turmaNome",
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 40),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("MÉDIA GERAL",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    mediaGeral.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  // Tabela
  Widget _tabelaDisciplinas() {
    final discs = _disciplinasNomes.keys.toList()
      ..sort((a, b) => _disciplinasNomes[a]!.compareTo(_disciplinasNomes[b]!));

    return Column(
      children: discs.map((discId) {
        final nome = _disciplinasNomes[discId]!;
        final medias = _mediasPorDisciplina[discId]!;
        final mediaFinal = _mediaFinalPorDisciplina[discId]!;
        final situacao = _situacao(mediaFinal);

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12.withOpacity(.06), blurRadius: 12),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header disciplina
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(nome,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _corSituacao(mediaFinal).withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      situacao,
                      style: TextStyle(
                        color: _corSituacao(mediaFinal),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 12),

              // Médias bimestrais
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _ordemBimestres.map((b) {
                  return Column(
                    children: [
                      Text(b.split(" ")[0],
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      Text(medias[b]!.toStringAsFixed(1)),
                    ],
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              const Text("Atividades avaliadas",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),

              // Atividades
              ..._atividadesAgrupadas[discId]!.entries.expand((bim) {
                return [
                  Text("• ${bim.key}",
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                  ...bim.value.map((atv) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(atv["titulo"]),
                          Text(
                            "${atv["nota"].toStringAsFixed(1)} (peso ${atv["peso"]})",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ];
              }),

              const Divider(),

              Text(
                "Média Final: ${mediaFinal.toStringAsFixed(1)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff6A5AE0),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Média geral
  double _calcularMediaGeral() {
    if (_mediaFinalPorDisciplina.isEmpty) return 0;

    double soma = 0;
    int qtd = 0;

    for (final m in _mediaFinalPorDisciplina.values) {
      soma += m;
      qtd++;
    }

    return qtd == 0 ? 0 : soma / qtd;
  }
}

// ======================================================================
//  ACUMULADOR
// ======================================================================

class _Acum {
  double total = 0;
  double peso = 0;

  void add(double n, double p) {
    total += n * p;
    peso += p;
  }
}