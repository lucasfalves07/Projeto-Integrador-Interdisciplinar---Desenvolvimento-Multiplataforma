// 🔥 FirestoreService — COMPLETO, OTIMIZADO E ALINHADO AO FIRESTORE
// Projeto Poliedro

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ============================================================================
  // 🔹 USUÁRIOS
  // ============================================================================

  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final doc = await _db.collection("users").doc(uid).get();
      return doc.data();
    } catch (e) {
      throw Exception("Erro ao buscar usuário: $e");
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> dados) async {
    try {
      await _db.collection('users').doc(uid).set({
        ...dados,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao atualizar perfil: $e");
    }
  }

  Future<void> setUserRole(String uid, String role) async {
    try {
      final normalized = role.trim().toLowerCase();
      await _db.collection('users').doc(uid).set({
        'tipo': normalized,
        'role': normalized,
        'perfil': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Erro ao definir função: $e');
    }
  }

  /// Pesquisa usuários por nome/email/RA
  Future<List<Map<String, dynamic>>> buscarUsuariosPorTermo(
    String termo, {
    String? tipo,
    int limit = 30,
  }) async {
    try {
      final t = termo.trim();
      if (t.isEmpty) return [];

      final results = <String, Map<String, dynamic>>{};

      // Email exato
      final byEmail = await _db
          .collection('users')
          .where('email', isEqualTo: t)
          .limit(limit)
          .get();

      for (final d in byEmail.docs) {
        results[d.id] = {'id': d.id, ...d.data()};
      }

      // RA exato
      final byRa = await _db
          .collection('users')
          .where('ra', isEqualTo: t)
          .limit(limit)
          .get();

      for (final d in byRa.docs) {
        results[d.id] = {'id': d.id, ...d.data()};
      }

      // Prefixo de nome
      Future<void> prefixSearch(String campo) async {
        final q = await _db
            .collection('users')
            .orderBy(campo)
            .startAt([t])
            .endAt(["$t\uf8ff"])
            .limit(limit)
            .get();

        for (final d in q.docs) {
          results[d.id] = {'id': d.id, ...d.data()};
        }
      }

      try {
        await prefixSearch('nomeLower');
      } catch (_) {
        try {
          await prefixSearch('nome');
        } catch (_) {}
      }

      final list = results.values.where((u) {
        if (tipo == null) return true;
        final v = (u['tipo'] ?? u['role'] ?? '').toString();
        return v == tipo;
      }).toList();

      list.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '')));

      return list.take(limit).toList();
    } catch (e) {
      throw Exception('Erro ao buscar usuários: $e');
    }
  }

  /// Define RA e sincroniza users ↔ alunos
  Future<void> setUserRA(String uid, String ra) async {
    try {
      final raTrim = ra.trim();

      // Atualiza users
      await _db.collection('users').doc(uid).set({
        'ra': raTrim,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final userData = (await _db.collection('users').doc(uid).get()).data() ?? {};
      final turmas = (userData['turmas'] as List?)?.map((e) => e.toString()).toList() ?? [];

      // Atualiza alunos
      await _db.collection('alunos').doc(uid).set({
        'uid': uid,
        'nome': userData['nome'] ?? '',
        'ra': raTrim,
        'turmas': turmas,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao definir RA: $e");
    }
  }

  /// Adiciona usuário em turmas
  Future<void> addUserToTurmas(String uid, List<String> turmaIds) async {
    if (turmaIds.isEmpty) return;

    try {
      final u = await _db.collection('users').doc(uid).get();
      final ra = (u.data()?['ra'] ?? '').toString();
      final marker = ra.isNotEmpty ? ra : uid;

      // Users
      await _db.collection('users').doc(uid).set({
        'turmas': FieldValue.arrayUnion(turmaIds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Alunos
      await _db.collection('alunos').doc(uid).set({
        'turmas': FieldValue.arrayUnion(turmaIds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Turmas
      for (final t in turmaIds) {
        await _db.collection('turmas').doc(t).set({
          'alunosIds': FieldValue.arrayUnion([marker]),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception("Erro ao adicionar às turmas: $e");
    }
  }

  Future<void> removeUserFromTurmas(String uid, List<String> turmaIds) async {
    if (turmaIds.isEmpty) return;

    try {
      final u = await _db.collection('users').doc(uid).get();
      final ra = (u.data()?['ra'] ?? '').toString();
      final marker = ra.isNotEmpty ? ra : uid;

      // users
      await _db.collection('users').doc(uid).set({
        'turmas': FieldValue.arrayRemove(turmaIds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // alunos
      await _db.collection('alunos').doc(uid).set({
        'turmas': FieldValue.arrayRemove(turmaIds),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // turmas
      for (final t in turmaIds) {
        await _db.collection('turmas').doc(t).set({
          'alunosIds': FieldValue.arrayRemove([marker]),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception("Erro ao remover das turmas: $e");
    }
  }

  // ============================================================================
  // 🔹 TURMAS
  // ============================================================================

  Future<void> criarTurma({
    required String nome,
    required String disciplina,
    required String professorId,
    String? anoSerie,
    String? turno,
    int? periodoLetivo,
    int capacidade = 30,
  }) async {
    try {
      final disciplinaRef = _db.collection("disciplinas").doc();
      final disciplinaId = disciplinaRef.id;

      // Cria disciplina
      await disciplinaRef.set({
        "id": disciplinaId,
        "nome": disciplina,
        "professorId": professorId,
        "turmaId": "",
        "criadoEm": FieldValue.serverTimestamp(),
      });

      // Cria turma
      final turmaRef = await _db.collection("turmas").add({
        "nome": nome,
        "anoSerie": anoSerie ?? "",
        "turno": turno ?? "",
        "periodoLetivo": periodoLetivo ?? DateTime.now().year,
        "capacidade": capacidade,
        "professorId": professorId,
        "disciplinas": [
          {"id": disciplinaId, "nome": disciplina}
        ],
        "alunos": [],
        "alunosIds": [],
        "criadoEm": FieldValue.serverTimestamp(),
      });

      // Vincula disciplina à turma
      await disciplinaRef.update({"turmaId": turmaRef.id});

      // Atualiza user
      await _db.collection("users").doc(professorId).set({
        "turmas": FieldValue.arrayUnion([turmaRef.id]),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao criar turma: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarTurmasDoProfessor(String professorId) async {
    try {
      final snap = await _db
          .collection('turmas')
          .where('professorId', isEqualTo: professorId)
          .get();

      final turmas = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (turmas.isNotEmpty) return turmas;

      final viaPerfil = await _listarTurmasViaPerfil(professorId);
      if (viaPerfil.isNotEmpty) return viaPerfil;

      return await _listarTurmasViaDisciplinas(professorId);
    } catch (e) {
      throw Exception("Erro ao listar turmas: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _listarTurmasViaPerfil(String professorId) async {
    final doc = await _db.collection('users').doc(professorId).get();
    final data = doc.data() ?? {};
    final ids = _extractTurmaIds(data['turmas']);

    if (ids.isEmpty) return [];

    final futures = ids.map((t) => _db.collection('turmas').doc(t).get());
    final snaps = await Future.wait(futures);

    return snaps
        .where((snap) => snap.exists)
        .map((snap) => {'id': snap.id, ...snap.data()!})
        .toList();
  }

  Future<List<Map<String, dynamic>>> _listarTurmasViaDisciplinas(String professorId) async {
    final disciplinas =
        await _db.collection('disciplinas').where('professorId', isEqualTo: professorId).get();

    final ids = disciplinas.docs
        .map((d) => (d['turmaId'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final list = <Map<String, dynamic>>[];

    for (final t in ids) {
      final snap = await _db.collection('turmas').doc(t).get();
      if (snap.exists) list.add({'id': snap.id, ...snap.data()!});
    }

    return list;
  }

  Set<String> _extractTurmaIds(dynamic raw) {
    final ids = <String>{};

    if (raw is String && raw.trim().isNotEmpty) {
      ids.add(raw.trim());
    } else if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          ids.add(item.trim());
        } else if (item is Map) {
          final value = item['id'] ?? item['turmaId'];
          if (value != null && value.toString().trim().isNotEmpty) {
            ids.add(value.toString().trim());
          }
        }
      }
    }

    return ids;
  }

  // ============================================================================
  // 🔹 ALUNOS
  // ============================================================================

  Future<void> addAlunoNaTurma({
    required String turmaId,
    required String nome,
    required String ra,
  }) async {
    try {
      // Turma
      await _db.collection("turmas").doc(turmaId).update({
        "alunos": FieldValue.arrayUnion([
          {"nome": nome, "ra": ra}
        ]),
        "alunosIds": FieldValue.arrayUnion([ra]),
      });

      // Coleção alunos
      await _db.collection("alunos").doc(ra).set({
        "nome": nome,
        "ra": ra,
        "status": "Ativo",
        "turmaId": turmaId,
        "criadoEm": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao adicionar aluno: $e");
    }
  }

  Future<void> removerAlunoDaTurma(String turmaId, String ra) async {
    try {
      final ref = _db.collection("turmas").doc(turmaId);
      final doc = await ref.get();

      final alunos = (doc['alunos'] as List?) ?? [];
      alunos.removeWhere((a) => a['ra'] == ra);

      await ref.update({
        "alunos": alunos,
        "alunosIds": FieldValue.arrayRemove([ra]),
      });
    } catch (e) {
      throw Exception("Erro ao remover aluno: $e");
    }
  }

  // ============================================================================
  // 🔹 MATERIAIS / ARQUIVOS
  // ============================================================================

  Future<Map<String, dynamic>?> uploadArquivoAtividade(String uid) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'mp4',
          'mov',
          'doc',
          'docx',
          'ppt',
          'pptx'
        ],
      );

      if (picked == null) return null;

      final file = picked.files.single;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('materiais/$uid/$fileName');

      final metadata = SettableMetadata(
        contentType: _definirContentType(file.extension),
        customMetadata: {
          'fileName': file.name,
          'size': file.size.toString(),
          'user': uid,
        },
      );

      UploadTask uploadTask;

      if (kIsWeb && file.bytes != null) {
        uploadTask = ref.putData(file.bytes!, metadata);
      } else if (file.path != null) {
        uploadTask = ref.putFile(File(file.path!), metadata);
      } else {
        throw Exception("Arquivo inválido.");
      }

      final snap = await uploadTask.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();

      return {
        'url': url,
        'nome': file.name,
        'ext': file.extension ?? "",
        'size': file.size,
        'path': snap.ref.fullPath,
      };
    } catch (e) {
      throw Exception("Erro ao enviar arquivo: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarMateriaisPorTurma(
    String turmaId, {
    int limit = 30,
  }) async {
    try {
      if (turmaId.isEmpty) return [];
      final snap =
          await _db.collection("materiais").where("turmaId", isEqualTo: turmaId).get();
      final materiais = snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
      materiais.sort(
        (a, b) => _asDate(b["criadoEm"]).compareTo(_asDate(a["criadoEm"])),
      );
      if (limit > 0 && materiais.length > limit) {
        return materiais.take(limit).toList();
      }
      return materiais;
    } catch (e) {
      throw Exception("Erro ao listar materiais da turma: $e");
    }
  }

  String _definirContentType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  // ============================================================================
  // 🔹 ATIVIDADES
  // ============================================================================

  Future<void> criarAtividade(Map<String, dynamic> atividade) async {
    try {
      final id = 'A${DateTime.now().millisecondsSinceEpoch}';

      await _db.collection("atividades").doc(id).set({
        "id": id,
        "professorId": atividade['professorId'],
        "turmaId": atividade['turmaId'],
        "disciplinaId": atividade['disciplinaId'],
        "titulo": atividade['titulo'],
        "descricao": atividade['descricao'] ?? "",
        "max": atividade["max"] ?? 10,
        "peso": atividade["peso"] ?? 1,
        "criadoEm": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Erro ao criar atividade: $e");
    }
  }

  Future<List<Map<String, dynamic>>> listarAtividades(String turmaId) async {
    try {
      final snap =
          await _db.collection("atividades").where("turmaId", isEqualTo: turmaId).get();
      return snap.docs.map((d) => {"id": d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao listar atividades: $e");
    }
  }

  Future<List<Map<String, dynamic>>> buscarAtividadesPorTurma(
    String turmaId, {
    int limit = 25,
  }) async {
    try {
      if (turmaId.isEmpty) return [];
      final atividades = await listarAtividades(turmaId);
      atividades.sort(
        (a, b) => _asDate(b["criadoEm"]).compareTo(_asDate(a["criadoEm"])),
      );
      if (limit > 0 && atividades.length > limit) {
        return atividades.take(limit).toList();
      }
      return atividades;
    } catch (e) {
      throw Exception("Erro ao buscar atividades da turma: $e");
    }
  }

  // ============================================================================
  // 🔹 NOTAS
  // ============================================================================

  Future<void> lancarNota(Map<String, dynamic> data) async {
    try {
      final id = "${data["atividadeId"]}_${data["alunoRa"]}";

      await _db.collection("notas").doc(id).set({
        "atividadeId": data["atividadeId"],
        "atividadeTitulo": data["atividadeTitulo"],
        "alunoRa": data["alunoRa"],
        "alunoNome": data["alunoNome"],
        "professorId": data["professorId"],
        "turmaId": data["turmaId"],
        "disciplinaId": data["disciplinaId"],
        "nota": data["nota"],
        "data": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Erro ao lançar nota: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getNotasPorTurma(String turmaId) async {
    try {
      final snap =
          await _db.collection("notas").where('turmaId', isEqualTo: turmaId).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      throw Exception("Erro ao buscar notas: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> streamNotasAluno(String alunoRa) {
    return _db
        .collection("notas")
        .where("alunoRa", isEqualTo: alunoRa)
        .snapshots()
        .map((s) => s.docs.map((d) => {"id": d.id, ...d.data()}).toList());
  }

  // ============================================================================
  // 🔹 CONFIG / PREFS
  // ============================================================================

  Future<Map<String, dynamic>?> getNotificationPrefs(String uid) async {
    final doc = await _db.collection('notification_prefs').doc(uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getAppMeta() async {
    final doc = await _db.collection('config').doc('app_meta').get();
    return doc.data();
  }

  Future<void> updateNotificationPrefs(String uid, Map<String, dynamic> prefs) async {
    await _db.collection('notification_prefs').doc(uid).set({
      ...prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================================
  // 🔹 EXPORTAÇÃO
  // ============================================================================

  Future<Map<String, dynamic>> exportarDadosDoUsuario(String uid) async {
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
  }

  Future<int> limparRascunhos(String uid) async {
    final snap =
        await _db.collection('rascunhos').where('uid', isEqualTo: uid).get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }

    return snap.docs.length;
  }

  DateTime _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      } catch (_) {}
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
