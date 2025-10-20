import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton (mantém cache global de autenticação e role)
  AuthService._internal() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        currentRole.value = null; // limpa cache ao sair
      } else {
        _loadAndCacheUserRole(user.uid);
      }
    });
  }

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cache reativo do papel do usuário logado: 'aluno' | 'professor' | null
  final ValueNotifier<String?> currentRole = ValueNotifier<String?>(null);

  /// Usuário logado atualmente
  User? get currentUser => _auth.currentUser;

  /// Stream de mudanças de login/logout
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // LOGIN / CADASTRO
  // ---------------------------------------------------------------------------

  /// Login com e-mail e senha
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _ensureUserDoc(user);
        await _loadAndCacheUserRole(user.uid);
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  /// Cadastro com e-mail e senha
  /// Padrão: cria conta com tipo = 'aluno' (pode ser sobrescrito)
  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password, {
    String tipoDefault = 'aluno',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _ensureUserDoc(user, tipoDefault: tipoDefault);
        currentRole.value = tipoDefault.toLowerCase();
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  /// Garante que exista um doc em `users/{uid}` e mantém campos essenciais atualizados
  Future<void> _ensureUserDoc(
    User user, {
    String tipoDefault = 'aluno',
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    final tipoPadrao = tipoDefault.toLowerCase().trim();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'nome': user.displayName ?? '',
        'tipo': tipoPadrao,
        'ra': '',
        'turmas': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = snap.data() ?? {};
      final tipoAtual = (data['tipo'] ?? data['role'] ?? '').toString().toLowerCase();

      // 🔁 Se não tiver tipo salvo, define o padrão
      await ref.set({
        if ((user.email ?? '').isNotEmpty) 'email': user.email,
        if ((user.displayName ?? '').isNotEmpty) 'nome': user.displayName,
        if (tipoAtual.isEmpty) 'tipo': tipoPadrao,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Carrega o papel do usuário (tipo/role) e armazena no cache
  Future<String?> _loadAndCacheUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final role = (data['tipo'] ?? data['role'] ?? '').toString().toLowerCase().trim();
      currentRole.value = role.isEmpty ? null : role;
      return role;
    } catch (_) {
      currentRole.value = null;
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PERFIL / USUÁRIO
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUserDoc([String? uid]) async {
    final theUid = uid ?? _auth.currentUser?.uid;
    if (theUid == null) return null;
    final doc = await _db.collection('users').doc(theUid).get();
    return doc.data();
  }

  /// Atualiza campos seguros do perfil do usuário
  Future<void> updateUserProfile(Map<String, dynamic> data, {String? uid}) async {
    final theUid = uid ?? _auth.currentUser?.uid;
    if (theUid == null) throw Exception('Usuário não autenticado');

    final safe = <String, dynamic>{};
    if (data.containsKey('telefone')) safe['telefone'] = data['telefone'];
    if (data.containsKey('theme')) safe['theme'] = data['theme'];
    if (data.containsKey('dateFormat')) safe['dateFormat'] = data['dateFormat'];
    if (data.containsKey('prefs')) safe['prefs'] = data['prefs'];
    if (data.containsKey('nome')) safe['nome'] = data['nome'];

    safe['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('users').doc(theUid).set(safe, SetOptions(merge: true));
  }

  /// Retorna o perfil do usuário (tipo/role)
  Future<String?> buscarPerfil([String? uid]) async {
    final theUid = uid ?? _auth.currentUser?.uid;
    if (theUid == null) return null;
    if (currentRole.value != null) return currentRole.value;
    return await _loadAndCacheUserRole(theUid);
  }

  Future<bool> isProfessor([String? uid]) async =>
      (await buscarPerfil(uid)) == 'professor';

  Future<bool> isAluno([String? uid]) async =>
      (await buscarPerfil(uid)) == 'aluno';

  /// Retorna lista de IDs das turmas associadas ao usuário
  Future<List<String>> getTurmas([String? uid]) async {
    final data = await getUserDoc(uid);
    final list = (data?['turmas'] as List?) ?? const [];
    return list.map((e) => e.toString()).toList();
  }

  // ---------------------------------------------------------------------------
  // BUSCAS para o professor
  // ---------------------------------------------------------------------------

  /// Buscar e-mail pelo RA
  Future<String?> buscarEmailPorRA(String ra) async {
    try {
      final q = await _db
          .collection('users')
          .where('ra', isEqualTo: ra)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.data()['email'] as String?;
      return null;
    } catch (e) {
      throw Exception('Erro ao buscar RA: $e');
    }
  }

  /// Buscar um aluno pelo e-mail
  Future<Map<String, dynamic>?> buscarAlunoPorEmail(String email) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .where(Filter.or(
          Filter('tipo', isEqualTo: 'aluno'),
          Filter('role', isEqualTo: 'aluno'),
        ))
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return {'id': q.docs.first.id, ...q.docs.first.data()};
  }

  /// Busca flexível de alunos (por nome, RA ou e-mail)
  Future<List<Map<String, dynamic>>> buscarAlunosPorTermo(
    String termo, {
    int limit = 15,
  }) async {
    final t = termo.trim();
    if (t.isEmpty) return [];

    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    // Busca por RA
    final byRa = await _db
        .collection('users')
        .where('ra', isEqualTo: t)
        .where('tipo', isEqualTo: 'aluno')
        .limit(limit)
        .get();

    // Busca por e-mail
    final byEmail = await _db
        .collection('users')
        .where('email', isEqualTo: t)
        .where('tipo', isEqualTo: 'aluno')
        .limit(limit)
        .get();

    // Busca por nome (prefixo)
    final end = t.substring(0, t.length - 1) +
        String.fromCharCode(t.codeUnitAt(t.length - 1) + 1);
    final byName = await _db
        .collection('users')
        .where('tipo', isEqualTo: 'aluno')
        .orderBy('nome')
        .startAt([t])
        .endBefore([end])
        .limit(limit)
        .get();

    void addAll(QuerySnapshot<Map<String, dynamic>> qs) {
      for (final d in qs.docs) {
        if (seen.add(d.id)) out.add({'id': d.id, ...d.data()});
      }
    }

    addAll(byRa);
    addAll(byEmail);
    addAll(byName);
    return out.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // SENHA / SESSÃO
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
    currentRole.value = null;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');
    final cred = EmailAuthProvider.credential(
      email: user.email ?? '',
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.delete();
    currentRole.value = null;
  }

  // ---------------------------------------------------------------------------
  // ERROS
  // ---------------------------------------------------------------------------

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'email-already-in-use':
        return 'E-mail já está em uso.';
      case 'weak-password':
        return 'A senha é muito fraca.';
      case 'user-disabled':
        return 'Usuário desativado.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      case 'operation-not-allowed':
        return 'Operação não permitida neste projeto.';
      default:
        return 'Erro: ${e.message ?? e.code}';
    }
  }
}
