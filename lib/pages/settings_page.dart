// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';
import 'package:poliedro_flutter/theme/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late final TabController _tabController;

  // ---------------- Perfil
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  String _formatoData = 'DD/MM/AAAA';

  // ---------------- Notificações
  bool _notifEntregaAtividades = true;
  bool _notifMensagens = true;
  bool _notifLeitura = false;
  bool _notifFalhaUpload = true;

  // ---------------- Segurança
  final _senhaAtualCtrl = TextEditingController();
  final _novaSenhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();

  // ---------------- Sobre
  String _versao = '2.5.0';
  String _ultimaAtualizacao = '15 de março de 2024';

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _telCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _novaSenhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 🔹 Carregamento inicial
  // ============================================================
  Future<void> _carregarDadosIniciais() async {
    try {
      if (_currentUser != null) {
        final u = await _firestore.getUserByUid(_currentUser!.uid);
        _nomeCtrl.text =
            (u?['nome'] ?? _currentUser!.displayName ?? '').toString();
        _emailCtrl.text = _currentUser!.email ?? (u?['email'] ?? '');
        _telCtrl.text = (u?['telefone'] ?? u?['phone'] ?? '').toString();

        final fmt = u?['dateFormat'] ?? u?['formatoData'];
        if (fmt != null) _formatoData = fmt.toString().toUpperCase();

        final prefs = await _firestore.getNotificationPrefs(_currentUser!.uid);
        if (prefs != null) {
          _notifEntregaAtividades =
              prefs['activityDelivery'] ?? _notifEntregaAtividades;
          _notifMensagens = prefs['messages'] ?? _notifMensagens;
          _notifLeitura = prefs['readReceipt'] ?? _notifLeitura;
          _notifFalhaUpload = prefs['uploadFailures'] ?? _notifFalhaUpload;
        }

        final meta = await _firestore.getAppMeta();
        _versao = (meta['version'] ?? _versao).toString();
        _ultimaAtualizacao =
            (meta['lastUpdate'] ?? _ultimaAtualizacao).toString();
      }
    } catch (e) {
      _toast('Erro ao carregar configurações: $e', error: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ============================================================
  // 🔹 Ações principais
  // ============================================================
  Future<void> _salvarPerfil(ThemeController themeController) async {
    if (_currentUser == null) return;
    try {
      await _currentUser!.updateDisplayName(_nomeCtrl.text.trim());
      await _firestore.updateUserProfile(_currentUser!.uid, {
        'nome': _nomeCtrl.text.trim(),
        'telefone': _telCtrl.text.trim(),
        'theme': themeController.isDarkMode ? 'dark' : 'light',
        'dateFormat': _formatoData,
      });
      _toast('Alterações de perfil salvas!');
    } catch (e) {
      _toast('Falha ao salvar perfil: $e', error: true);
    }
  }

  Future<void> _salvarNotificacoes() async {
    if (_currentUser == null) return;
    try {
      await _firestore.updateNotificationPrefs(_currentUser!.uid, {
        'activityDelivery': _notifEntregaAtividades,
        'messages': _notifMensagens,
        'readReceipt': _notifLeitura,
        'uploadFailures': _notifFalhaUpload,
      });
      _toast('Preferências de notificações salvas!');
    } catch (e) {
      _toast('Falha ao salvar notificações: $e', error: true);
    }
  }

  Future<void> _alterarSenha() async {
    final nova = _novaSenhaCtrl.text;
    final conf = _confirmaSenhaCtrl.text;

    if (nova.isEmpty || conf.isEmpty || nova != conf) {
      _toast('Nova senha e confirmação não coincidem.', error: true);
      return;
    }

    try {
      await _currentUser?.updatePassword(nova);
      _senhaAtualCtrl.clear();
      _novaSenhaCtrl.clear();
      _confirmaSenhaCtrl.clear();
      _toast('Senha alterada com sucesso!');
    } catch (e) {
      _toast(
        'Não foi possível alterar a senha diretamente. '
        'Por segurança, faça login novamente e tente de novo.',
        error: true,
      );
    }
  }

  Future<void> _exportarDados() async {
    if (_currentUser == null) return;
    try {
      final dump = await _firestore.exportarDadosDoUsuario(_currentUser!.uid);
      _toast('Exportação concluída (${dump.keys.length} coleções).');
    } catch (e) {
      _toast('Falha ao exportar dados: $e', error: true);
    }
  }

  Future<void> _limparRascunhos() async {
    if (_currentUser == null) return;
    try {
      final removidos = await _firestore.limparRascunhos(_currentUser!.uid);
      _toast('Rascunhos removidos: $removidos');
    } catch (e) {
      _toast('Falha ao limpar rascunhos: $e', error: true);
    }
  }

  // ============================================================
  // 🔹 Utilitários
  // ============================================================
  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? Colors.red[700]
            : Theme.of(context).colorScheme.primary.withOpacity(0.9),
      ),
    );
  }

  Widget _section(String title, {EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _card(Widget child) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _linha2(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  // ============================================================
  // 🔹 Interface principal
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context, listen: true);

    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = themeController.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        title: Text('Configurações',
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: isDark ? Colors.grey[850] : Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.orange,
              labelColor: isDark ? Colors.white : Colors.black,
              tabs: const [
                Tab(icon: Icon(Icons.person), text: 'Perfil'),
                Tab(icon: Icon(Icons.notifications), text: 'Notificações'),
                Tab(icon: Icon(Icons.security), text: 'Segurança'),
                Tab(icon: Icon(Icons.storage), text: 'Dados'),
                Tab(icon: Icon(Icons.info_outline), text: 'Sobre'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _tabPerfil(themeController),
          _tabNotificacoes(),
          _tabSeguranca(),
          _tabDados(),
          _tabSobre(),
        ],
      ),
    );
  }

  // ============================================================
  // 🔹 TABS
  // ============================================================
  Widget _tabPerfil(ThemeController themeController) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Informações do Perfil'),
            _linha2(
              TextField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome completo'),
              ),
              TextField(
                controller: _emailCtrl,
                enabled: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
            ),
            const SizedBox(height: 12),
            _linha2(
              TextField(
                controller: _telCtrl,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              DropdownButtonFormField<String>(
                value: themeController.isDarkMode ? 'Escuro' : 'Claro',
                items: const [
                  DropdownMenuItem(value: 'Claro', child: Text('Claro')),
                  DropdownMenuItem(value: 'Escuro', child: Text('Escuro')),
                ],
                onChanged: (v) {
                  if (v == 'Escuro') {
                    themeController.setTheme(ThemeMode.dark);
                  } else {
                    themeController.setTheme(ThemeMode.light);
                  }
                },
                decoration: const InputDecoration(labelText: 'Tema'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _salvarPerfil(themeController),
                child: const Text('Salvar alterações'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabNotificacoes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Notificações'),
            SwitchListTile(
              title: const Text('Entrega de atividades'),
              value: _notifEntregaAtividades,
              onChanged: (v) => setState(() => _notifEntregaAtividades = v),
            ),
            SwitchListTile(
              title: const Text('Mensagens'),
              value: _notifMensagens,
              onChanged: (v) => setState(() => _notifMensagens = v),
            ),
            SwitchListTile(
              title: const Text('Confirmação de leitura'),
              value: _notifLeitura,
              onChanged: (v) => setState(() => _notifLeitura = v),
            ),
            SwitchListTile(
              title: const Text('Falhas de upload'),
              value: _notifFalhaUpload,
              onChanged: (v) => setState(() => _notifFalhaUpload = v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _salvarNotificacoes,
                child: const Text('Salvar preferências'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabSeguranca() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Alterar senha'),
            TextField(
              controller: _novaSenhaCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova senha'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmaSenhaCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirmar nova senha'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _alterarSenha,
                child: const Text('Alterar senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabDados() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Gerenciar Dados'),
                const Text(
                  'Baixe seus dados salvos (turmas, atividades, notas etc.)',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _exportarDados,
                  child: const Text('Exportar dados'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Limpar rascunhos'),
                const Text(
                  'Remove atividades e materiais salvos como rascunho.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _limparRascunhos,
                  child: const Text('Limpar rascunhos antigos'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabSobre() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('Sobre o Sistema'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Versão',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_versao),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Última atualização',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(_ultimaAtualizacao),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: () {}, child: const Text('Ver changelog')),
            TextButton(onPressed: () {}, child: const Text('Central de ajuda')),
            TextButton(onPressed: () {}, child: const Text('Entrar em contato')),
          ],
        ),
      ),
    );
  }
}
