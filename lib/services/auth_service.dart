import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// =============================================================================
/// 🔐 AuthService — autenticação, sessão e sincronização com Firestore
/// =============================================================================
class AuthService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  AuthService._internal() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        currentRole.value = null;
      } else {
        _loadAndCacheUserRole(user.uid);
      }
    });
  }

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Perfil: aluno / professor / admin
  final ValueNotifier<String?> currentRole = ValueNotifier<String?>(null);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =============================================================================
  // LOGIN E CADASTRO
  // =============================================================================

  /// Login: aceita **email** ou **RA**
  Future<User?> signIn(String login, String password) async {
    try {
      String email = login.trim();

      // RA → converte para email
      if (!login.contains('@')) {
        final q = await _db
            .collection('users')
            .where('ra', isEqualTo: login.trim())
            .limit(1)
            .get();

        if (q.docs.isEmpty) throw Exception('RA não encontrado.');

        email = q.docs.first.data()['email'] ?? "";
        if (email.isEmpty) throw Exception('E-mail não associado ao RA.');
      }

      // Firebase login
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

  /// Cadastro padrão (aluno)
  Future<User?> signUp({
    required String email,
    required String password,
    String tipoDefault = 'aluno',
    String? nome,
    String? ra,
    List<String>? turmasDefault,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;

      if (user != null) {
        await _ensureUserDoc(
          user,
          tipoDefault: tipoDefault,
          nome: nome,
          ra: ra,
          turmasDefault: turmasDefault,
        );
        currentRole.value = tipoDefault.toLowerCase().trim();
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  // Alias para compatibilidade
  Future<User?> signInWithEmailAndPassword(String email, String password) =>
      signIn(email, password);

  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password, {
    String tipoDefault = 'aluno',
    List<String>? turmasDefault,
  }) =>
      signUp(
        email: email,
        password: password,
        tipoDefault: tipoDefault,
        turmasDefault: turmasDefault,
      );

  // =============================================================================
  // FIRESTORE SYNC
  // =============================================================================

  /// Garante que o documento users/{uid} exista e esteja atualizado
  Future<void> _ensureUserDoc(
    User user, {
    String tipoDefault = 'aluno',
    String? nome,
    String? ra,
    List<String>? turmasDefault,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    final tipo = tipoDefault.toLowerCase().trim();

    // Criar do zero
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'nome': nome ?? user.displayName ?? '',
        'tipo': tipo,
        'role': tipo,
        'perfil': tipo,
        'ra': ra ?? '',
        'turmas': turmasDefault ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Atualizar doc existente
    final data = snap.data() ?? {};
    final tipoAtual =
        (data['tipo'] ?? data['role'] ?? data['perfil'] ?? "").toString();

    await ref.set({
      if ((user.email ?? '').isNotEmpty) 'email': user.email,
      if ((nome ?? user.displayName ?? '').isNotEmpty)
        'nome': nome ?? user.displayName,
      if (turmasDefault != null && turmasDefault.isNotEmpty)
        'turmas': turmasDefault,
      if (tipoAtual.trim().isEmpty) ...{
        'tipo': tipo,
        'role': tipo,
        'perfil': tipo,
      },
      if (ra != null && ra.isNotEmpty) 'ra': ra,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Carrega e armazena "aluno", "professor" ou "admin"
  Future<String?> _loadAndCacheUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};

      final role =
          (data['tipo'] ?? data['role'] ?? data['perfil'] ?? '').toString();

      final trimmed = role.toLowerCase().trim();
      currentRole.value = trimmed.isEmpty ? null : trimmed;

      return currentRole.value;
    } catch (_) {
      currentRole.value = null;
      return null;
    }
  }

  // =============================================================================
  // PERFIL / CONSULTAS
  // =============================================================================

  Future<Map<String, dynamic>?> getUserDoc([String? uid]) async {
    final id = uid ?? currentUser?.uid;
    if (id == null) return null;

    final doc = await _db.collection('users').doc(id).get();
    return doc.data();
  }

  Future<void> updateUserProfile(Map<String, dynamic> data, {String? uid}) async {
    final id = uid ?? currentUser?.uid;
    if (id == null) throw Exception('Usuário não autenticado.');

    await _db.collection('users').doc(id).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> buscarPerfil([String? uid]) async {
    final id = uid ?? currentUser?.uid;
    if (id == null) return null;

    if (currentRole.value != null) return currentRole.value!;
    return await _loadAndCacheUserRole(id);
  }

  Future<bool> isProfessor([String? uid]) async =>
      (await buscarPerfil(uid)) == 'professor';

  Future<bool> isAluno([String? uid]) async =>
      (await buscarPerfil(uid)) == 'aluno';

  Future<List<String>> getTurmas([String? uid]) async {
    final data = await getUserDoc(uid);
    if (data == null) return [];

    final raw = data['turmas'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) return [raw];

    return [];
  }

  // =============================================================================
  // BUSCAS
  // =============================================================================

  Future<String?> buscarEmailPorRA(String ra) async {
    try {
      final q = await _db
          .collection('users')
          .where('ra', isEqualTo: ra)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) return q.docs.first.data()['email'];
      return null;
    } catch (e) {
      throw Exception('Erro ao buscar RA: $e');
    }
  }

  Future<Map<String, dynamic>?> buscarAlunoPorEmail(String email) async {
    final q = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .where('tipo', isEqualTo: 'aluno')
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return {'id': q.docs.first.id, ...q.docs.first.data()};
  }

  Future<List<Map<String, dynamic>>> buscarAlunosPorTermo(
    String termo, {
    int limit = 20,
  }) async {
    final t = termo.trim();
    if (t.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    // RA
    final byRa = await _db
        .collection('users')
        .where('ra', isEqualTo: t)
        .where('tipo', isEqualTo: 'aluno')
        .limit(limit)
        .get();

    // Email
    final byEmail = await _db
        .collection('users')
        .where('email', isEqualTo: t)
        .where('tipo', isEqualTo: 'aluno')
        .limit(limit)
        .get();

    // Busca por nome — prefix search
    final upper = t.substring(0, t.length - 1) +
        String.fromCharCode(t.codeUnitAt(t.length - 1) + 1);

    final byName = await _db
        .collection('users')
        .where('tipo', isEqualTo: 'aluno')
        .orderBy('nome')
        .startAt([t])
        .endBefore([upper])
        .limit(limit)
        .get();

    void add(QuerySnapshot<Map<String, dynamic>> qs) {
      for (var d in qs.docs) {
        if (seen.add(d.id)) {
          results.add({'id': d.id, ...d.data()});
        }
      }
    }

    add(byRa);
    add(byEmail);
    add(byName);

    return results.take(limit).toList();
  }

  // =============================================================================
  // SESSÃO / SENHA
  // =============================================================================

  Future<void> signOut() async {
    await _auth.signOut();
    currentRole.value = null;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado.');

    final cred = EmailAuthProvider.credential(
      email: user.email ?? "",
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

  // =============================================================================
  // ERROS
  // =============================================================================

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-mail inválido';
      case 'user-not-found':
        return 'Usuário não encontrado';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'email-already-in-use':
        return 'E-mail já está em uso';
      case 'weak-password':
        return 'Senha muito fraca';
      case 'user-disabled':
        return 'Usuário desativado';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco.';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      default:
        return 'Erro: ${e.message ?? e.code}';
    }
  }
}