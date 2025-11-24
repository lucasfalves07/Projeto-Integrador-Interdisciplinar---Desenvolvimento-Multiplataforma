import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final db = FirebaseFirestore.instance;

  print("\n\n=============== TURMAS ===============");
  final turmas = await db.collection("turmas").get();
  for (var t in turmas.docs) {
    print("\nTURMA >>> ${t.id}");
    print(t.data());

    final mensagens = await t.reference.collection("mensagens").get();
    print("  MENSAGENS: ${mensagens.docs.length}");

    final materiais = await t.reference.collection("materiais").get();
    print("  MATERIAIS: ${materiais.docs.length}");
  }

  print("\n\n=============== DISCIPLINAS ===============");
  final disciplinas = await db.collection("disciplinas").get();
  for (var d in disciplinas.docs) {
    print("\nDISCIPLINA >>> ${d.id}");
    print(d.data());
  }

  print("\n\n=============== ATIVIDADES ===============");
  final atividades = await db.collection("atividades").get();
  for (var a in atividades.docs) {
    print("\nATIVIDADE >>> ${a.id}");
    print(a.data());
  }

  print("\n\n=============== ALUNOS ===============");
  final alunos = await db.collection("alunos").get();
  for (var a in alunos.docs) {
    print("\nALUNO >>> ${a.id}");
    print(a.data());
  }

  print("\n\n=============== THREADS ===============");
  final threads = await db.collection("threads").get();
  for (var th in threads.docs) {
    print("\nTHREAD >>> ${th.id}");
    print(th.data());

    final itens = await th.reference.collection("itens").get();
    print("  ITEMS: ${itens.docs.length}");
  }

  print("\n\n✅ SELECT COMPLETO FINALIZADO ✅\n\n");
}
// correcao dart
