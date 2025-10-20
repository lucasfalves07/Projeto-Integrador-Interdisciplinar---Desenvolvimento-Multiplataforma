import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

// Se você tiver o arquivo firebase_options.dart (gerado pelo Firebase CLI)
// descomente a linha abaixo e substitua pelo seu caminho:
// import 'firebase_options.dart';

Future<void> main() async {
  // Inicializa o Firebase (ajuste com suas opções, se necessário)
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // descomente se tiver
  );

  final firestore = FirebaseFirestore.instance;

  print('🔍 Iniciando leitura completa do banco de dados Firestore...\n');

  final collections = await firestore.listCollections();

  for (final collection in collections) {
    await _printCollection(collection);
  }

  print('\n✅ Leitura finalizada com sucesso.');
}

/// Percorre recursivamente coleções, documentos e subcoleções
Future<void> _printCollection(CollectionReference collection, [String indent = '']) async {
  print('${indent}📂 Coleção: ${collection.id}');
  final querySnapshot = await collection.get();

  for (final doc in querySnapshot.docs) {
    print('${indent}  📄 Documento ID: ${doc.id}');
    print('${indent}  ➜ Dados: ${doc.data()}');

    // Subcoleções dentro do documento
    final subcollections = await doc.reference.listCollections();
    for (final sub in subcollections) {
      await _printCollection(sub, '$indent    ');
    }
  }

  print('${indent}--------------------------------------------');
}
