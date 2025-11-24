// ignore_for_file: avoid_print

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("🚀 INICIANDO SEED (APENAS O QUE FALTA)...");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;

  // ------------------------------------------------------------------
  // ✅ Carregar dados existentes (turmas, disciplinas, alunos)
  // ------------------------------------------------------------------

  final turmas = await db.collection("turmas").get();
  final disciplinas = await db.collection("disciplinas").get();
  final alunos = await db.collection("alunos").get();

  print("📌 Turmas: ${turmas.size}");
  print("📌 Disciplinas: ${disciplinas.size}");
  print("📌 Alunos: ${alunos.size}")

  // ------------------------------------------------------------------
  // ✅ 1. Criar MURAL DAS TURMAS (mensagens públicas)
  // ------------------------------------------------------------------

  print("📌 Criando mensagens públicas...");

  for (final t in turmas.docs) {
    final turmaId = t.id;
    final professorId = t["professorId"];

    // Já existe mural?
    final muralSnap = await db
        .collection("turmas")
        .doc(turmaId)
        .collection("mensagens")
        .limit(1)
        .get();

    if (muralSnap.docs.isNotEmpty) {
      print("✅ Turma $turmaId já tem mural, pulando...");
      continue;
    }

    // Mensagem do sistema
    await db.collection("turmas").doc(turmaId).collection("mensagens").add({
      "autorNome": "Sistema",
      "autorUid": "system",
      "mensagem": "Bem-vindos à turma! Aqui serão postados avisos.",
      "data": FieldValue.serverTimestamp(),
      "tipo": "turma",
      "visivelPara": "todos",
    });

    // Mensagem do professor
    await db.collection("turmas").doc(turmaId).collection("mensagens").add({
      "autorNome": "Professor",
      "autorUid": professorId,
      "mensagem": "Confiram os materiais no tópico da disciplina!",
      "data": FieldValue.serverTimestamp(),
      "tipo": "turma",
      "visivelPara": "todos",
    });

    print("✅ Mural criado para a turma $turmaId");
  }

  // ------------------------------------------------------------------
  // ✅ 2. Criar THREADS 1:1 (professor ↔ aluno)
  // ------------------------------------------------------------------

  print("📌 Criando threads individuais...");

  for (final aluno in alunos.docs) {
    final turmaId = aluno["turmaId"];
    final professorId = turmas.docs
        .firstWhere((t) => t.id == turmaId)["professorId"];

    // Verificar se a thread já existe
    final threadExist = await db
        .collection("threads")
        .where("alunoRa", isEqualTo: aluno.id)
        .limit(1)
        .get();

    if (threadExist.docs.isNotEmpty) {
      continue;
    }

    // Criar thread
    final threadRef = await db.collection("threads").add({
      "turmaId": turmaId,
      "alunoRa": aluno.id,
      "professorId": professorId,
      "participantes": [professorId, aluno.id],
      "aberto": true,
      "criadoEm": FieldValue.serverTimestamp(),
    });

    // Primeira mensagem
    await threadRef.collection("itens").add({
      "fromUid": professorId,
      "toUid": aluno.id,
      "texto": "Olá! Este é o canal para dúvidas individuais 😊",
      "tipo": "individual",
      "createdAt": FieldValue.serverTimestamp(),
    });

    print("✅ Criada thread → aluno ${aluno.id}");
  }

  // ------------------------------------------------------------------
  // ✅ 3. Criar TÓPICOS + MATERIAIS (se não existir)
  // ------------------------------------------------------------------

  print("📌 Criando tópicos + materiais...");

  final topicosBase = [
    {"titulo": "Introdução", "ordem": 1},
    {"titulo": "Unidade 1", "ordem": 2},
    {"titulo": "Unidade 2", "ordem": 3},
  ];

  for (final disc in disciplinas.docs) {
    final topicosSnap = await db
        .collection("disciplinas")
        .doc(disc.id)
        .collection("topicos")
        .limit(1)
        .get();

    if (topicosSnap.docs.isNotEmpty) {
      continue;
    }

    for (final tp in topicosBase) {
      final topRef = await db
          .collection("disciplinas")
          .doc(disc.id)
          .collection("topicos")
          .add({
        "titulo": tp["titulo"],
        "ordem": tp["ordem"],
        "criadoEm": FieldValue.serverTimestamp(),
      });

      await topRef.collection("materiais").add({
        "titulo": "Material Base",
        "tipo": "pdf",
        "url": "https://exemplo.com/material.pdf",
        "criadoEm": FieldValue.serverTimestamp()
      });
    }

    print("✅ Tópicos criados para disciplina ${disc.id}");
  }

  // ------------------------------------------------------------------
  // ✅ 4. Criar ATIVIDADES + NOTAS
  // ------------------------------------------------------------------

  print("📌 Criando atividades + notas...");

  final atividadesBase = [
    {
      "titulo": "Prova Bimestral",
      "descricao": "Avaliação geral.",
      "max": 10,
      "peso": 2,
    },
    {
      "titulo": "Exercícios",
      "descricao": "Lista avaliativa.",
      "max": 10,
      "peso": 1,
    },
  ];

  for (final turma in turmas.docs) {
    final turmaId = turma.id;

    // pegar disciplina da turma
    final disc = disciplinas.docs
        .firstWhere((d) => d["turmaId"] == turmaId);

    for (final atv in atividadesBase) {
      final atvRef = await db.collection("atividades").add({
        ...atv,
        "turmaId": turmaId,
        "disciplinaId": disc.id,
        "professorId": turma["professorId"],
        "criadoEm": FieldValue.serverTimestamp(),
      });

      // Criar notas
      for (final aluno in alunos.docs) {
        if (aluno["turmaId"] != turmaId) continue;

        final nota = Random().nextInt(5) + 6; // 6 a 10

        // 🔹 Salvar em atividades/{id}/notas/{ra}
        await atvRef.collection("notas").doc(aluno.id).set({
          "nota": nota.toDouble(),
          "alunoRa": aluno.id,
          "data": FieldValue.serverTimestamp(),
        });

        // 🔹 Salvar em alunos/{ra}/notas/{atv}
        await db
            .collection("alunos")
            .doc(aluno.id)
            .collection("notas")
            .doc(atvRef.id)
            .set({
          "nota": nota.toDouble(),
          "atividadeId": atvRef.id,
          "disciplinaId": disc.id,
          "turmaId": turmaId,
          "peso": atv["peso"],
          "max": atv["max"],
          "titulo": atv["titulo"],
          "data": FieldValue.serverTimestamp(),
        });
      }
    }

    print("✅ Atividades criadas → turma $turmaId");
  }

  print("\n🎉 SEED FINALIZADO — APENAS O QUE FALTAVA FOI CRIADO!");
}
