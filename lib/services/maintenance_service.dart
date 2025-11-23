import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Serviço de manutenção/migração executado no cliente
/// Professor só altera dados aos quais possui acesso.
class MaintenanceService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Executa TODAS as rotinas de manutenção.
  Future<Map<String, int>> runAll({bool dryRun = false}) async {
    final out = <String, int>{};

    out['users'] = await _fixUsers(dryRun: dryRun);
    out['turmas'] = await _fixTurmas(dryRun: dryRun);
    out['alunos'] = await _fixAlunos(dryRun: dryRun);
    out['mensagens'] = await _fixMensagens(dryRun: dryRun);
    out['notas'] = await _fixNotas(dryRun: dryRun);

    return out;
  }

  // ============================================================================
  // 🔹 ALUNOS
  // ============================================================================
  Future<int> _fixAlunos({required bool dryRun}) async {
    int fixes = 0;

    try {
      final users = await _db
          .collection('users')
          .where('tipo', isEqualTo: 'aluno')
          .get();

      final batch = _db.batch();

      // Cria/atualiza alunos com base em users
      for (final u in users.docs) {
        final data = u.data();
        final ra = (data['ra'] ?? '').toString();
        final nome = (data['nome'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final turmas =
            ((data['turmas'] as List?)?.map((e) => e.toString()).toList()) ??
                <String>[];

        for (final turmaId in turmas) {
          final id = ra.isNotEmpty ? ra : '${u.id}_$turmaId';

          fixes++;
          if (!dryRun) {
            batch.set(
              _db.collection('alunos').doc(id),
              {
                'idUser': u.id,
                'nome': nome,
                'ra': ra.isNotEmpty ? ra : u.id,
                'email': email,
                'turmaId': turmaId,
                'media':
                    (data['media'] ?? 0) is num ? (data['media'] ?? 0) : 0,
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }
        }
      }

      // Migra docs cujo ID != RA
      final alunosSnap = await _db.collection('alunos').get();

      for (final d in alunosSnap.docs) {
        final ra = (d.data()['ra'] ?? '').toString();

        // se não tem ra ou já está correto, pula
        if (ra.isEmpty || d.id == ra) continue;

        fixes++;
        if (!dryRun) {
          batch.set(
            _db.collection('alunos').doc(ra),
            d.data(),
            SetOptions(merge: true),
          );
          batch.delete(d.reference);
        }
      }

      if (!dryRun && fixes > 0) await batch.commit();
      return fixes;
    } catch (e) {
      print("Erro _fixAlunos: $e");
      return fixes;
    }
  }

  // ============================================================================
  // 🔹 USERS
  // ============================================================================
  Future<int> _fixUsers({required bool dryRun}) async {
    int fixes = 0;

    final q1 =
        await _db.collection('users').where('tipo', isEqualTo: 'aluno').get();
    final q2 =
        await _db.collection('users').where('role', isEqualTo: 'aluno').get();
    final q3 = await _db
        .collection('users')
        .where('perfil', isEqualTo: 'aluno')
        .get();

    final seen = <String>{};
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final q in [q1, q2, q3]) {
      for (final d in q.docs) {
        if (seen.add(d.id)) docs.add(d);
      }
    }

    final batch = _db.batch();

    for (final d in docs) {
      final data = d.data();
      final update = <String, dynamic>{};

      // tipo vazio → preenche com perfil
      if ((data['tipo'] == null || (data['tipo'] as String).isEmpty) &&
          data['perfil'] is String) {
        update['tipo'] = (data['perfil'] as String).toLowerCase();
      }

      // turmas mal formatado
      if (data['turmas'] is String &&
          (data['turmas'] as String).trim().isNotEmpty) {
        update['turmas'] = [(data['turmas'] as String).trim()];
      }

      if (update.isNotEmpty) {
        fixes++;
        if (!dryRun) {
          update['updatedAt'] = FieldValue.serverTimestamp();
          batch.set(d.reference, update, SetOptions(merge: true));
        }
      }
    }

    if (!dryRun && fixes > 0) await batch.commit();
    return fixes;
  }

  // ============================================================================
  // 🔹 TURMAS
  // ============================================================================
  Future<int> _fixTurmas({required bool dryRun}) async {
    int fixes = 0;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final qs = await _db
        .collection('turmas')
        .where('professorId', isEqualTo: uid)
        .get();

    final others =
        await _db.collection('turmas').where('professorId', isNull: true).get();

    final all = [...qs.docs, ...others.docs];
    final batch = _db.batch();

    for (final d in all) {
      final data = d.data();

      if (data['professorId'] == null ||
          (data['professorId'] as String).isEmpty) {
        final fromDisc = (data['disciplinas'] is List &&
                (data['disciplinas'] as List).isNotEmpty)
            ? (((data['disciplinas'] as List).first as Map)['professorId']
                    ?.toString() ??
                '')
            : '';

        final value = fromDisc.isNotEmpty ? fromDisc : uid;

        fixes++;
        if (!dryRun) {
          batch.set(
            d.reference,
            {'professorId': value},
            SetOptions(merge: true),
          );
        }
      }
    }

    if (!dryRun && fixes > 0) await batch.commit();
    return fixes;
  }

  // ============================================================================
  // 🔹 MENSAGENS
  // ============================================================================
  Future<int> _fixMensagens({required bool dryRun}) async {
    int fixes = 0;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final turmas = await _db
        .collection('turmas')
        .where('professorId', isEqualTo: uid)
        .get();

    final turmaIds = turmas.docs.map((e) => e.id).toList();

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    // Busca mensagens por turma (evitando whereIn > 10)
    for (var i = 0; i < turmaIds.length; i += 10) {
      final slice = turmaIds.sublist(
        i,
        (i + 10 > turmaIds.length) ? turmaIds.length : i + 10,
      );

      if (slice.isEmpty) continue;

      final snap =
          await _db.collection('mensagens').where('turmaId', whereIn: slice).get();
      docs.addAll(snap.docs);
    }

    // Mensagens diretas
    docs.addAll(
        (await _db.collection('mensagens').where('de', isEqualTo: uid).get())
            .docs);
    docs.addAll((await _db
            .collection('mensagens')
            .where('toUid', isEqualTo: uid)
            .get())
        .docs);

    final seen = <String>{};
    final unique = docs.where((d) => seen.add(d.id)).toList();

    final batch = _db.batch();

    for (final d in unique) {
      final data = d.data();
      final update = <String, dynamic>{};

      // mensagem → padroniza com 'texto'
      if ((data['mensagem'] == null || data['mensagem'] == '') &&
          data['texto'] is String) {
        update['mensagem'] = data['texto'];
      }

      // timestamp legacy → enviadaEm
      if (data['enviadaEm'] == null && data['timestamp'] != null) {
        final ts = _toTimestamp(data['timestamp']);
        if (ts != null) update['enviadaEm'] = ts;
      }

      // monta chatKey (mensagem direta)
      if (data['toUid'] != null && data['chatKey'] == null && data['de'] != null) {
        final a = data['de'].toString();
        final b = data['toUid'].toString();
        update['chatKey'] = a.compareTo(b) <= 0 ? '${a}_${b}' : '${b}_${a}';
      }

      if (update.isNotEmpty) {
        fixes++;
        if (!dryRun) {
          batch.set(d.reference, update, SetOptions(merge: true));
        }
      }
    }

    if (!dryRun && fixes > 0) await batch.commit();
    return fixes;
  }

  // ============================================================================
  // 🔹 NOTAS
  // ============================================================================
  Future<int> _fixNotas({required bool dryRun}) async {
    int fixes = 0;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final qs = await _db.collection('notas').get();
    final batch = _db.batch();

    for (final d in qs.docs) {
      final data = d.data();
      final update = <String, dynamic>{};

      // Corrige timestamp
      if (data['dataLancamento'] is String) {
        final ts = _toTimestamp(data['dataLancamento']);
        if (ts != null) update['dataLancamento'] = ts;
      }

      // valor → nota
      if (data['nota'] == null && data['valor'] != null) {
        final v = data['valor'];
        if (v is num) update['nota'] = v.toDouble();
      }

      // preencher turmaId e professorId a partir da atividade
      if ((data['turmaId'] == null || data['professorId'] == null) &&
          data['atividadeId'] != null) {
        try {
          final atv = await _db
              .collection('atividades')
              .doc(data['atividadeId'].toString())
              .get();
          final atvData = atv.data() ?? {};

          update['turmaId'] ??= atvData['turmaId'];
          update['professorId'] ??= atvData['professorId'];
        } catch (_) {}
      }

      if (update.isNotEmpty) {
        fixes++;
        if (!dryRun) {
          batch.set(d.reference, update, SetOptions(merge: true));
        }
      }
    }

    if (!dryRun && fixes > 0) await batch.commit();
    return fixes;
  }

  // ============================================================================
  // 🔹 CONVERSÃO SEGURO DE TIMESTAMP
  // ============================================================================
  Timestamp? _toTimestamp(dynamic v) {
    try {
      if (v == null) return null;

      if (v is Timestamp) return v;

      if (v is Map && v['_seconds'] is int) {
        return Timestamp(v['_seconds'], (v['_nanoseconds'] ?? 0));
      }

      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return Timestamp.fromDate(dt);
      }
    } catch (_) {}
    return null;
  }
}
