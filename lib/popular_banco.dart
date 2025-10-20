import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCURuhRVAi5raqbj8ACPL8Yv3O6Dcdk8OI",
      authDomain: "poliedro-flutter.firebaseapp.com",
      projectId: "poliedro-flutter",
      storageBucket: "poliedro-flutter.firebasestorage.app",
      messagingSenderId: "504037958633",
      appId: "1:504037958633:web:3c1f359cb86381ea246178",
      measurementId: "G-98QV6XDF7W",
    ),
  );

  final db = FirebaseFirestore.instance;

  // 🔹 Usuários
  final users = [
    {
      "ra": "1001",
      "nome": "Ana Souza",
      "email": "ana@aluno.com",
      "senha": "123456",
      "perfil": "aluno",
      "turmas": ["T1-Computação"]
    },
    {
      "ra": "1002",
      "nome": "Bruno Lima",
      "email": "bruno@aluno.com",
      "senha": "123456",
      "perfil": "aluno",
      "turmas": ["T1-Computação"]
    },
    {
      "ra": "2001",
      "nome": "Carlos Pereira",
      "email": "carlos@aluno.com",
      "senha": "123456",
      "perfil": "aluno",
      "turmas": ["T2-História"]
    },
    {
      "ra": "2002",
      "nome": "Daniela Rocha",
      "email": "daniela@aluno.com",
      "senha": "123456",
      "perfil": "aluno",
      "turmas": ["T2-História"]
    },
    {
      "ra": "2003",
      "nome": "Eduardo Gomes",
      "email": "eduardo@aluno.com",
      "senha": "123456",
      "perfil": "aluno",
      "turmas": ["T2-História"]
    },
    {
      "ra": "prof1",
      "nome": "Prof. João Silva",
      "email": "joao@prof.com",
      "senha": "123456",
      "perfil": "professor",
      "turmas": ["T1-Computação"]
    },
    {
      "ra": "prof2",
      "nome": "Prof. Maria Oliveira",
      "email": "maria@prof.com",
      "senha": "123456",
      "perfil": "professor",
      "turmas": ["T2-História"]
    },
    {
      "ra": "prof3",
      "nome": "Prof. Ricardo Santos",
      "email": "ricardo@prof.com",
      "senha": "123456",
      "perfil": "professor",
      "turmas": ["T1-Computação", "T2-História"]
    },
  ];

  for (var u in users) {
    await db.collection("users").doc(u["ra"].toString()).set(u);
  }

  // 🔹 Turmas
  final turmas = {
    "T1-Computação": {
      "nome": "1º Semestre - Computação",
      "professores": ["prof1", "prof3"],
      "alunos": ["1001", "1002"]
    },
    "T2-História": {
      "nome": "1º Semestre - História",
      "professores": ["prof2", "prof3"],
      "alunos": ["2001", "2002", "2003"]
    }
  };

  for (var t in turmas.entries) {
    await db.collection("turmas").doc(t.key.toString()).set(t.value);
  }

  // 🔹 Disciplinas
  final disciplinas = {
    "disc1": {"nome": "Matemática", "turmaId": "T1-Computação"},
    "disc2": {"nome": "Português", "turmaId": "T1-Computação"},
    "disc3": {"nome": "História", "turmaId": "T2-História"},
    "disc4": {"nome": "Ciências", "turmaId": "T2-História"},
  };

  for (var d in disciplinas.entries) {
    await db.collection("disciplinas").doc(d.key.toString()).set(d.value);
  }

  // 🔹 Materiais
  await db.collection("materiais").doc("mat1").set({
    "disciplinaId": "disc1",
    "titulo": "Aula 1 - Introdução",
    "tipo": "pdf",
    "url": "https://exemplo.com/aula1.pdf",
    "criadoPor": "prof1",
    "visivelPara": ["T1-Computação"]
  });

  await db.collection("materiais").doc("mat2").set({
    "disciplinaId": "disc2",
    "titulo": "Aula 2 - Gramática",
    "tipo": "link",
    "url": "https://exemplo.com/aula2",
    "criadoPor": "prof3",
    "visivelPara": ["T1-Computação"]
  });

  // 🔹 Atividades
  await db.collection("atividades").doc("atv1").set({
    "disciplinaId": "disc1",
    "titulo": "Prova Matemática",
    "peso": 2.0,
    "max": 10
  });

  await db.collection("atividades").doc("atv2").set({
    "disciplinaId": "disc3",
    "titulo": "Trabalho História",
    "peso": 1.0,
    "max": 5
  });

  // 🔹 Notas
  await db.collection("notas").doc("nota1").set({
    "atividadeId": "atv1",
    "alunoUid": "1001",
    "valor": 8.5
  });

  await db.collection("notas").doc("nota2").set({
    "atividadeId": "atv2",
    "alunoUid": "2001",
    "valor": 4.0
  });

  // 🔹 Mensagens
  await db.collection("mensagens").doc("msg1").set({
    "de": "prof1",
    "para": "1001",
    "texto": "Olá Ana, não esqueça da prova semana que vem!",
    "timestamp": DateTime.now().millisecondsSinceEpoch,
  });

  await db.collection("mensagens").doc("msg2").set({
    "de": "2001",
    "para": "prof2",
    "texto": "Professora, enviei o trabalho de História no e-mail.",
    "timestamp": DateTime.now().millisecondsSinceEpoch,
  });

  print("✅ Banco COMPLETO com RA + senha populado com sucesso!");
}
