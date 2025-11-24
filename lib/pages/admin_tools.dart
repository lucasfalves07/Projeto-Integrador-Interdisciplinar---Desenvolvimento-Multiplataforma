import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:poliedro_flutter/services/maintenance_service.dart';

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key});
  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage> {
  final _svc = MaintenanceService();
  bool _running = false;
  bool _dryRun = true;
  Map<String, int>? _result;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '-';
    return Scaffold(
      appBar: AppBar(title: const Text('Ferramentas · Manutenção')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuário atual: $uid', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            SwitchListTile(
              value: !_dryRun,
              onChanged: (v) => setState(() => _dryRun = !v),
              title: const Text('Aplicar correções (desmarcado = Dry-Run)'),
              subtitle: const Text('Dry-Run apenas lista possíveis mudanças'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.build),
              label: Text(_running ? 'Executando...' : 'Executar migração (minhas turmas/dados)'),
            ),
            const SizedBox(height: 16),
            if (_result != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resultado', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('users: ${_result!['users'] ?? 0}'),
                      Text('turmas: ${_result!['turmas'] ?? 0}'),
                      Text('alunos: ${_result!['alunos'] ?? 0}'),
                      Text('mensagens: ${_result!['mensagens'] ?? 0}'),
                      Text('notas: ${_result!['notas'] ?? 0}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _run() async {
    setState(() { _running = true; _result = null; });
    try {
      final res = await _svc.runAll(dryRun: _dryRun);
      setState(() { _result = res; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Concluído: ${res.toString()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }
}