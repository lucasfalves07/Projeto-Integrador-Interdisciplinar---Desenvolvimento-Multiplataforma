import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';
import 'package:poliedro_flutter/services/auth_service.dart';

class AdminUsuariosPage extends StatefulWidget {
  const AdminUsuariosPage({super.key});

  @override
  State<AdminUsuariosPage> createState() => _AdminUsuariosPageState();
}

class _AdminUsuariosPageState extends State<AdminUsuariosPage> {
  final _fs = FirestoreService();
  final _auth = AuthService();

  final _searchCtrl = TextEditingController();
  final _raCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  List<Map<String, dynamic>> _result = [];
  List<Map<String, dynamic>> _turmas = [];

  @override
  void initState() {
    super.initState();
    _loadTurmas();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _raCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTurmas() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final qs = await FirebaseFirestore.instance
        .collection('turmas')
        .where('professorId', isEqualTo: uid)
        .get();

    setState(() {
      _turmas = qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  Future<void> _search() async {
    final t = _searchCtrl.text.trim();
    if (t.isEmpty) return;

    setState(() => _loading = true);

    try {
      final res =
          await _fs.buscarUsuariosPorTermo(t, tipo: 'aluno', limit: 30);
      setState(() => _result = res);
    } catch (e) {
      _snack('Erro na busca: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _dialogVincularRA(Map<String, dynamic> user) async {
    _raCtrl.text = (user['ra'] ?? '').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vincular RA'),
        content: TextField(
          controller: _raCtrl,
          decoration: const InputDecoration(labelText: 'RA do aluno'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _fs.setUserRA(user['id'] as String, _raCtrl.text.trim());
      _snack('RA atualizado');
      _search();
    } catch (e) {
      _snack('Erro ao salvar RA: $e', error: true);
    }
  }

  Future<void> _dialogTurmas(Map<String, dynamic> user) async {
    final uid = user['id'] as String;
    final turmas = List<Map<String, dynamic>>.from(_turmas);

    final atuais =
        ((user['turmas'] as List?)?.map((e) => e.toString()).toSet()) ??
            <String>{};

    final selec = {...atuais};

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            title: const Text('Vincular às turmas'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in turmas)
                    CheckboxListTile(
                      value: selec.contains(t['id']),
                      title: Text((t['nome'] ?? 'Turma').toString()),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) selec.add(t['id']);
                          else selec.remove(t['id']);
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      final toAdd = selec.difference(atuais).toList();
      final toRem = atuais.difference(selec).toList();

      if (toAdd.isNotEmpty) await _fs.addUserToTurmas(uid, toAdd);
      if (toRem.isNotEmpty) await _fs.removeUserFromTurmas(uid, toRem);

      _snack('Turmas atualizadas');
      _search();
    } catch (e) {
      _snack('Erro ao atualizar turmas: $e', error: true);
    }
  }

  Future<void> _alterarPapel(Map<String, dynamic> user) async {
    final atual = (user['tipo'] ?? user['role'] ?? 'aluno').toString();
    final novo = atual == 'aluno' ? 'professor' : 'aluno';

    try {
      await _fs.setUserRole(user['id'] as String, novo);
      _snack('Papel alterado para "$novo"');
      _search();
    } catch (e) {
      _snack('Erro ao alterar papel: $e', error: true);
    }
  }

  Future<void> _enviarResetSenha(Map<String, dynamic> user) async {
    final email = (user['email'] ?? '').toString();

    if (email.isEmpty) {
      _snack('Usuário sem e-mail cadastrado', error: true);
      return;
    }

    try {
      await _auth.resetPassword(email);
      _snack('Link de redefinição enviado para $email');
    } catch (e) {
      _snack('Erro ao enviar redefinição: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · Usuários'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nome, RA ou e-mail',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _result.isEmpty
                ? const Center(child: Text('Nenhum usuário encontrado'))
                : ListView.separated(
                    itemCount: _result.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final u = _result[i];
                      final nome = (u['nome'] ?? '').toString();
                      final email = (u['email'] ?? '').toString();
                      final ra = (u['ra'] ?? '').toString();
                      final role = (u['tipo'] ?? u['role'] ?? 'aluno').toString();
                      final turmas = (u['turmas'] as List?)?.length ?? 0;

                      return ListTile(
                        title: Text(nome.isEmpty ? '(Sem nome)' : nome),
                        subtitle: Text(
                          [
                            if (email.isNotEmpty) email,
                            if (ra.isNotEmpty) 'RA: $ra',
                            'Perfil: $role',
                            'Turmas: $turmas',
                          ].join('  ·  '),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _dialogVincularRA(u),
                              child: const Text('Vincular RA'),
                            ),
                            OutlinedButton(
                              onPressed: () => _dialogTurmas(u),
                              child: const Text('Gerenciar turmas'),
                            ),
                            OutlinedButton(
                              onPressed: () => _alterarPapel(u),
                              child: Text(role == 'aluno'
                                  ? 'Promover'
                                  : 'Rebaixar'),
                            ),
                            TextButton(
                              onPressed: () => _enviarResetSenha(u),
                              child: const Text('Reset senha'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}