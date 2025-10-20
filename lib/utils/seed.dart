import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final db = FirebaseFirestore.instance;
  print('🔥 Iniciando seed do banco de dados...');

  // -------------------------------
  // USERS
  // -------------------------------
  final users = [
    {
      "uid": "spfyADFZNedwruzGnDfl2ML1yC53",
      "nome": "Prof. Lucas Andrade",
      "email": "lucas@sistemapoliedro.com.br",
      "tipo": "professor",
      "disciplinas": ["D1"],
      "turmas": ["T1A"]
    },
    {
      "uid": "oWLZVUt914Zw6wx5Db8gxU6Miqm1",
      "nome": "Prof. João Carvalho",
      "email": "joao@sistemapoliedro.com.br",
      "tipo": "professor",
      "disciplinas": ["D2"],
      "turmas": ["T1B"]
    },
    {
      "uid": "c7pB5U0xlwbNOUjFnAApo6o5JEY2",
      "nome": "Jorge Almeida",
      "email": "jorge@alunosistemapoliedro.com.br",
      "tipo": "aluno",
      "ra": "A12345",
      "turmas": ["T1A"]
    },
    {
      "uid": "YhGeMDpFEkQOanMNsJ0jVsN3jXW2",
      "nome": "Carla Menezes",
      "email": "carla@alunosistemapoliedro.com.br",
      "tipo": "aluno",
      "ra": "A67890",
      "turmas": ["T1B"]
    },
  ];

  for (final u in users) {
    await db.collection('users').doc(u['uid'] as String).set(u, SetOptions(merge: true));
    print('✅ Usuário ${u['nome']} salvo');
  }

  // -------------------------------
  // TURMAS
  // -------------------------------
  final turmas = [
    {
      "id": "T1A",
      "nome": "Turma 1A - Matemática",
      "professorId": "spfyADFZNedwruzGnDfl2ML1yC53",
      "alunos": ["c7pB5U0xlwbNOUjFnAApo6o5JEY2"],
      "disciplinas": ["D1"]
    },
    {
      "id": "T1B",
      "nome": "Turma 1B - Português",
      "professorId": "oWLZVUt914Zw6wx5Db8gxU6Miqm1",
      "alunos": ["YhGeMDpFEkQOanMNsJ0jVsN3jXW2"],
      "disciplinas": ["D2"]
    },
  ];

  for (final t in turmas) {
    await db.collection('turmas').doc(t['id'] as String).set(t, SetOptions(merge: true));
    print('🏫 Turma ${t['nome']} criada');
  }

  // -------------------------------
  // DISCIPLINAS
  // -------------------------------
  final disciplinas = [
    {"id": "D1", "nome": "Matemática", "professorId": "spfyADFZNedwruzGnDfl2ML1yC53"},
    {"id": "D2", "nome": "Português", "professorId": "oWLZVUt914Zw6wx5Db8gxU6Miqm1"},
  ];

  for (final d in disciplinas) {
    await db.collection('disciplinas').doc(d['id'] as String).set(d, SetOptions(merge: true));
    print('📘 Disciplina ${d['nome']} salva');
  }

  // -------------------------------
  // ATIVIDADES
  // -------------------------------
  final atividades = [
    {
      "id": "A1",
      "titulo": "Prova 1 - Matemática",
      "turmaId": "T1A",
      "disciplinaId": "D1",
      "max": 10,
      "peso": 2
    },
    {
      "id": "A2",
      "titulo": "Redação 1 - Português",
      "turmaId": "T1B",
      "disciplinaId": "D2",
      "max": 10,
      "peso": 1
    },
  ];

  for (final a in atividades) {
    await db.collection('atividades').doc(a['id'] as String).set(a, SetOptions(merge: true));
    print('📝 Atividade ${a['titulo']} criada');
  }

  // -------------------------------
  // NOTAS
  // -------------------------------
  final notas = [
    {
      "id": "N1",
      "atividadeId": "A1",
      "alunoUid": "c7pB5U0xlwbNOUjFnAApo6o5JEY2",
      "nota": 8.5,
      "dataLancamento": DateTime.now().toIso8601String()
    },
    {
      "id": "N2",
      "atividadeId": "A2",
      "alunoUid": "YhGeMDpFEkQOanMNsJ0jVsN3jXW2",
      "nota": 9.2,
      "dataLancamento": DateTime.now().toIso8601String()
    },
  ];

  for (final n in notas) {
    await db.collection('notas').doc(n['id'] as String).set(n, SetOptions(merge: true));
    print('📊 Nota ${n['id']} lançada');
  }

  // -------------------------------
  // MENSAGENS
  // -------------------------------
  final mensagens = [
    {
      "id": "M1",
      "texto": "Bem-vindo à Turma 1A! Vamos começar os estudos de Matemática.",
      "de": "spfyADFZNedwruzGnDfl2ML1yC53",
      "turmaId": "T1A",
      "timestamp": DateTime.now().toIso8601String()
    },
    {
      "id": "M2",
      "texto": "Lembrem-se de entregar a Redação 1 até sexta-feira!",
      "de": "oWLZVUt914Zw6wx5Db8gxU6Miqm1",
      "turmaId": "T1B",
      "timestamp": DateTime.now().toIso8601String()
    },
  ];

  for (final m in mensagens) {
    await db.collection('mensagens').doc(m['id'] as String).set(m, SetOptions(merge: true));
    print('💬 Mensagem ${m['id']} criada');
  }

  print('\n✨ Seed concluído com sucesso!');
}
