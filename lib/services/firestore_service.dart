// lib/services/firestore_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =======================================================================
  // 🔹 USUÁRIOS
  // =======================================================================
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception("Erro ao buscar usuário: $e");
    }
  }

  Future<void> updateUserField(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection("users").doc(uid).update(data);
    } catch (e) {
      throw Exception("Erro ao atualizar usuário: $e");
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection("users").doc(uid).set(
        {
          ...data,
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception("Erro ao atualizar perfil: $e");
    }
  }

  /// 🔔 Salva ou atualiza o token FCM do usuário logado
  Future<void> salvarTokenFcm(String uid, String token) async {
    try {
      await _db.collection("users").doc(uid).set({
        "fcmToken": token,
        "tokenUpdatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao salvar token FCM: $e");
    }
  }

  // =======================================================================
  // ⚙️ CONFIGURAÇÕES / PREFS / META
  // =======================================================================
  Future<Map<String, dynamic>?> getNotificationPrefs(String uid) async {
    try {
      final doc = await _db
          .collection("users")
          .doc(uid)
          .collection("prefs")
          .doc("notifications")
          .get();
      return doc.data() ?? {};
    } catch (e) {
      print("Erro getNotificationPrefs: $e");
      return {};
    }
  }

  Future<void> updateNotificationPrefs(
      String uid, Map<String, dynamic> prefs) async {
    try {
      await _db
          .collection("users")
          .doc(uid)
          .collection("prefs")
          .doc("notifications")
          .set(
        {
          ...prefs,
          "updatedAt": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception("Erro ao atualizar notificações: $e");
    }
  }

  Future<Map<String, dynamic>> getAppMeta() async {
    try {
      final doc = await _db.collection("app_meta").doc("global").get();
      return doc.data() ?? {};
    } catch (e) {
      print("Erro getAppMeta: $e");
      return {};
    }
  }

  // =======================================================================
  // 🧑‍🏫 TURMAS
  // =======================================================================
  Future<void> criarTurma({
    required String nome,
    required String disciplina,
    required String professorId,
  }) async {
    try {
      await _db.collection("turmas").add({
        "nome": nome,
        "disciplina": disciplina,
        "professorId": professorId,
        "alunos": [],
        "criadoEm": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Erro ao criar turma: $e");
    }
  }

  Future<void> adicionarAlunoNaTurma(
      String turmaId, String nomeAluno, String ra) async {
    try {
      final turmaRef = _db.collection("turmas").doc(turmaId);
      await turmaRef.update({
        "alunos": FieldValue.arrayUnion([
          {"nome": nomeAluno, "ra": ra}
        ]),
      });
    } catch (e) {
      throw Exception("Erro ao adicionar aluno: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarTurmasDoProfessor(
      String professorId) async {
    try {
      final snapshot = await _db
          .collection("turmas")
          .where("professorId", isEqualTo: professorId)
          .get();
      return snapshot.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao listar turmas: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarTurmasDoAluno(String alunoUid) async {
    try {
      final snapshot = await _db
          .collection("turmas")
          .where("alunos", arrayContains: alunoUid)
          .get();
      return snapshot.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao listar turmas do aluno: $e");
    }
  }

  // =======================================================================
  // 📝 ATIVIDADES
  // =======================================================================
  Future<void> criarAtividade(Map<String, dynamic> atividade) async {
    try {
      await _db.collection("atividades").add({
        "titulo": atividade["titulo"],
        "disciplinaId": atividade["disciplinaId"],
        "turmaId": atividade["turmaId"],
        "professorId": atividade["professorId"],
        "max": atividade["max"],
        "peso": atividade["peso"],
        "dataCriacao": FieldValue.serverTimestamp(),
        "draft": atividade["draft"] ?? false,
      });
    } catch (e) {
      throw Exception("Erro ao criar atividade: $e");
    }
  }

  Future<List<Map<String, dynamic>>> buscarAtividadesPorTurma(
      String turmaId) async {
    try {
      final snapshot = await _db
          .collection("atividades")
          .where("turmaId", isEqualTo: turmaId)
          .orderBy("dataCriacao", descending: true)
          .get();
      return snapshot.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao buscar atividades: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> streamAtividadesPorTurmas(
      List<String> turmaIds) {
    return _streamWhereInChunked(
      collection: 'atividades',
      field: 'turmaId',
      values: turmaIds,
      orderBy: 'dataCriacao',
      descending: true,
    );
  }

  // =======================================================================
  // 🎯 NOTAS E DESEMPENHO
  // =======================================================================
  Future<void> lancarNota({
    required String atividadeId,
    required String alunoUid,
    required double nota,
    required String professorId,
  }) async {
    try {
      await _db.collection("notas").doc("${atividadeId}_$alunoUid").set({
        "atividadeId": atividadeId,
        "alunoUid": alunoUid,
        "professorId": professorId,
        "nota": nota,
        "dataLancamento": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Erro ao lançar nota: $e");
    }
  }

  Future<List<Map<String, dynamic>>> buscarNotasAluno(String alunoUid) async {
    try {
      final snapshot =
          await _db.collection("notas").where("alunoUid", isEqualTo: alunoUid).get();
      return snapshot.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao buscar notas: $e");
    }
  }

  Future<double> calcularMediaTurma(String turmaId) async {
    try {
      final atividadesSnap =
          await _db.collection("atividades").where("turmaId", isEqualTo: turmaId).get();
      if (atividadesSnap.docs.isEmpty) return 0;

      double somaNotas = 0;
      int totalNotas = 0;

      for (final atividade in atividadesSnap.docs) {
        final notasSnap = await _db
            .collection("notas")
            .where("atividadeId", isEqualTo: atividade.id)
            .get();
        for (final n in notasSnap.docs) {
          somaNotas += (n.data()["nota"] ?? 0).toDouble();
          totalNotas++;
        }
      }
      return totalNotas == 0 ? 0 : somaNotas / totalNotas;
    } catch (e) {
      print("Erro calcularMediaTurma: $e");
      return 0;
    }
  }

  Stream<List<Map<String, dynamic>>> streamNotasAluno(String alunoUid) {
    return _db
        .collection('notas')
        .where('alunoUid', isEqualTo: alunoUid)
        .orderBy('dataLancamento', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {"id": d.id, ...d.data()}).toList());
  }

  // =======================================================================
  // 📘 MATERIAIS
  // =======================================================================
  Future<void> adicionarMaterial({
    required String titulo,
    required String professorId,
    required List<String> turmasDesignadas,
    required String url,
    String? disciplina,
    String? fileName,
    num? fileSize,
    String status = "ready",
  }) async {
    try {
      await _db.collection("materiais").add({
        "titulo": titulo,
        "professorId": professorId,
        "turmasDesignadas": turmasDesignadas,
        "disciplina": disciplina ?? "",
        "url": url,
        "fileName": fileName ?? "",
        "fileSize": fileSize ?? 0,
        "status": status,
        "dataUpload": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Erro ao adicionar material: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarMateriaisPorTurma(
      String turmaId) async {
    try {
      final snapshot = await _db
          .collection("materiais")
          .where("turmasDesignadas", arrayContains: turmaId)
          .orderBy("dataUpload", descending: true)
          .get();
      return snapshot.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao listar materiais: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> streamMateriaisPorTurmas(
      List<String> turmaIds) {
    if (turmaIds.isEmpty) return Stream.value([]);
    return _db
        .collection("materiais")
        .where("turmasDesignadas", arrayContainsAny: turmaIds)
        .orderBy("dataUpload", descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {"id": d.id, ...d.data()}).toList());
  }

  // =======================================================================
  // 📤 EXPORTAÇÃO / LIMPEZA
  // =======================================================================
  Future<Map<String, dynamic>> exportarDadosDoUsuario(String uid) async {
    try {
      final turmas =
          await _db.collection("turmas").where("professorId", isEqualTo: uid).get();
      final atividades =
          await _db.collection("atividades").where("professorId", isEqualTo: uid).get();
      final notas =
          await _db.collection("notas").where("professorId", isEqualTo: uid).get();

      return {
        "turmas": turmas.docs.map((d) => d.data()).toList(),
        "atividades": atividades.docs.map((d) => d.data()).toList(),
        "notas": notas.docs.map((d) => d.data()).toList(),
      };
    } catch (e) {
      throw Exception("Erro ao exportar dados: $e");
    }
  }

  Future<int> limparRascunhos(String uid) async {
    int totalRemovidos = 0;
    try {
      final colecoes = ["atividades", "materiais"];
      for (final col in colecoes) {
        final query = await _db
            .collection(col)
            .where("professorId", isEqualTo: uid)
            .where("status", isEqualTo: "rascunho")
            .get();

        for (final doc in query.docs) {
          await doc.reference.delete();
          totalRemovidos++;
        }
      }
    } catch (e) {
      print("Erro ao limpar rascunhos: $e");
    }
    return totalRemovidos;
  }

  // =======================================================================
  // ⚙️ HELPERS INTERNOS
  // =======================================================================
  Stream<List<Map<String, dynamic>>> _streamWhereInChunked({
    required String collection,
    required String field,
    required List<String> values,
    required String orderBy,
    bool descending = true,
  }) {
    if (values.isEmpty) return Stream.value([]);

    if (values.length <= 10) {
      return _db
          .collection(collection)
          .where(field, whereIn: values)
          .orderBy(orderBy, descending: descending)
          .snapshots()
          .map((s) => s.docs.map((d) => {"id": d.id, ...d.data()}).toList());
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final subs = <StreamSubscription>[];
    final blocos = <int, List<Map<String, dynamic>>>{};

    List<List<String>> _chunk(List<String> list, int size) {
      final result = <List<String>>[];
      for (var i = 0; i < list.length; i += size) {
        result.add(list.sublist(i, (i + size > list.length) ? list.length : i + size));
      }
      return result;
    }

    void _emit() {
      final all = blocos.values.expand((e) => e).toList();
      all.sort((a, b) {
        final ma = (a[orderBy] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final mb = (b[orderBy] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return mb.compareTo(ma);
      });
      controller.add(all);
    }

    final chunks = _chunk(values, 10);
    for (var i = 0; i < chunks.length; i++) {
      final idx = i;
      final sub = _db
          .collection(collection)
          .where(field, whereIn: chunks[i])
          .orderBy(orderBy, descending: descending)
          .snapshots()
          .listen((snap) {
        blocos[idx] = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
        _emit();
      });
      subs.add(sub);
    }

    controller.onCancel = () async {
      for (final s in subs) {
        await s.cancel();
      }
    };

    return controller.stream;
  }
}
