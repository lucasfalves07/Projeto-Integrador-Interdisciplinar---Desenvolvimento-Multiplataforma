import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poliedro_flutter/services/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class MateriaisAlunoPage extends StatefulWidget {
  const MateriaisAlunoPage({super.key});

  @override
  State<MateriaisAlunoPage> createState() => _MateriaisAlunoPageState();
}

class _MateriaisAlunoPageState extends State<MateriaisAlunoPage> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirestoreService();

  String _search = '';
  String _disciplinaSelecionada = 'Todas as disciplinas';
  List<String> _turmaIds = [];
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _carregarTurmasDoAluno();
  }

  Future<void> _carregarTurmasDoAluno() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final user = await _fs.getUserByUid(uid);
    final turmas = (user?['turmas'] as List?) ?? [];
    setState(() {
      _turmaIds = turmas.map((e) => e.toString()).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: _turmaIds.isEmpty
                  ? const _EmptyState(text: 'Nenhuma turma encontrada.')
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _fs.streamMateriaisPorTurmas(_turmaIds),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Erro ao carregar materiais:\n${snap.error}',
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        final dados = snap.data ?? [];

                        final disciplinas = <String>{
                          'Todas as disciplinas',
                          ...dados
                              .map((e) => (e['disciplina'] ?? '').toString())
                              .where((e) => e.isNotEmpty),
                        }.toList()
                          ..sort();

                        Iterable<Map<String, dynamic>> filtrados = dados;

                        if (_disciplinaSelecionada != 'Todas as disciplinas') {
                          filtrados = filtrados.where(
                            (m) => (m['disciplina'] ?? '') == _disciplinaSelecionada,
                          );
                        }

                        if (_search.isNotEmpty) {
                          final s = _search.toLowerCase();
                          filtrados = filtrados.where((m) {
                            final t = (m['titulo'] ?? '').toString().toLowerCase();
                            final d = (m['disciplina'] ?? '').toString().toLowerCase();
                            return t.contains(s) || d.contains(s);
                          });
                        }

                        final lista = filtrados.toList()
                          ..sort((a, b) {
                            final ma = _toMillis(a['dataUpload']);
                            final mb = _toMillis(b['dataUpload']);
                            return (mb ?? 0).compareTo(ma ?? 0);
                          });

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: _SearchField(
                                controller: _searchCtrl,
                                hint: 'Buscar materiais...',
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _DisciplinaDropdown(
                                value: _disciplinaSelecionada,
                                items: disciplinas,
                                onChanged: (v) => setState(() => _disciplinaSelecionada = v),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: lista.isEmpty
                                  ? const _EmptyState(text: 'Nenhum material encontrado.')
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                      itemCount: lista.length,
                                      itemBuilder: (context, i) {
                                        final m = lista[i];
                                        return _MaterialCard(
                                          titulo: (m['titulo'] ?? '') as String,
                                          disciplina: (m['disciplina'] ?? '') as String,
                                          tipo: (m['tipo'] ?? _inferTipo(m['url'])) as String,
                                          tamanhoMb: m['fileSize']?.toString(),
                                          dataUpload: m['dataUpload'],
                                          url: (m['url'] ?? '') as String,
                                          isNovo: _isNovo(m['dataUpload']),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Materiais',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                'Apostilas e conteúdos disponíveis',
                style: textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isNovo(dynamic ts) {
    final ms = _toMillis(ts);
    if (ms == null) return false;
    final pub = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(pub).inDays <= 7;
  }

  static int? _toMillis(dynamic ts) {
    try {
      if (ts == null) return null;
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      if (ts is int) return ts;
      if (ts is String) {
        final n = int.tryParse(ts);
        if (n != null) return n;
        final d = DateTime.tryParse(ts);
        if (d != null) return d.millisecondsSinceEpoch;
      }
      if (ts is Map && ts['_seconds'] is int) {
        return (ts['_seconds'] as int) * 1000;
      }
    } catch (_) {}
    return null;
  }

  static String _inferTipo(dynamic url) {
    final u = (url ?? '').toString().toLowerCase();
    if (u.endsWith('.pdf')) return 'pdf';
    if (u.contains('youtube') || u.endsWith('.mp4') || u.endsWith('.mov')) return 'video';
    return 'link';
  }
}

/// 🔍 Campo de busca
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xfff7f7fb),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffe6e6ee)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffe6e6ee)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }
}

/// 🎓 Dropdown de disciplinas
class _DisciplinaDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DisciplinaDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem<String>(
                value: e,
                child: Text(e.isEmpty ? 'Sem disciplina' : e),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xfff7f7fb),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffe6e6ee)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xffe6e6ee)),
        ),
      ),
    );
  }
}

/// 📚 Card de material
class _MaterialCard extends StatelessWidget {
  final String titulo;
  final String disciplina;
  final String tipo;
  final String? tamanhoMb;
  final dynamic dataUpload;
  final String url;
  final bool isNovo;

  const _MaterialCard({
    required this.titulo,
    required this.disciplina,
    required this.tipo,
    required this.tamanhoMb,
    required this.dataUpload,
    required this.url,
    required this.isNovo,
  });

  IconData get _leadingIcon {
    switch (tipo.toLowerCase()) {
      case 'video':
        return Icons.videocam_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color get _leadingBg {
    switch (tipo.toLowerCase()) {
      case 'video':
        return const Color(0xffffecd7);
      case 'link':
        return const Color(0xfff3e2ff);
      default:
        return const Color(0xffe9efff);
    }
  }

  Color get _leadingIconColor {
    switch (tipo.toLowerCase()) {
      case 'video':
        return const Color(0xfff08a24);
      case 'link':
        return const Color(0xff8a4cff);
      default:
        return const Color(0xff3b6cff);
    }
  }

  String get _badgeText {
    switch (tipo.toLowerCase()) {
      case 'video':
        return 'Vídeo';
      case 'link':
        return 'Link';
      default:
        return 'PDF';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy');
    final ms = _toMillis(dataUpload);
    final dataStr = ms == null ? '-' : df.format(DateTime.fromMillisecondsSinceEpoch(ms));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xfffbf9ff),
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _leadingBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_leadingIcon, color: _leadingIconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Tag(text: _badgeText),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disciplina.isEmpty ? '—' : disciplina,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            (tamanhoMb == null || tamanhoMb!.isEmpty)
                                ? '-'
                                : '${tamanhoMb!} MB',
                            style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 8),
                          Text(
                            'Publicado em $dataStr',
                            style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                          ),
                          const Spacer(),
                          if (isNovo) const _NovoChip(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PrimaryActionButton(
                  icon: Icons.visibility,
                  label: 'Visualizar',
                  onTap: () async => _openUrl(url),
                ),
                const SizedBox(width: 10),
                if (tipo.toLowerCase() != 'link')
                  _SecondaryActionButton(
                    icon: Icons.file_download_outlined,
                    label: 'Baixar',
                    onTap: () async => _openUrl(url),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static int? _toMillis(dynamic ts) {
    try {
      if (ts == null) return null;
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      if (ts is int) return ts;
      if (ts is String) {
        final n = int.tryParse(ts);
        if (n != null) return n;
        final d = DateTime.tryParse(ts);
        if (d != null) return d.millisecondsSinceEpoch;
      }
      if (ts is Map && ts['_seconds'] is int) {
        return (ts['_seconds'] as int) * 1000;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _openUrl(String link) async {
    if (link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}

/// Badge
class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        border: Border.all(color: const Color(0xffe6e6ee)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }
}

class _NovoChip extends StatelessWidget {
  const _NovoChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffff7f0a),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Novo',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xffff9800),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black87),
      label: Text(label,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Color(0xffd7d7e0)),
      ),
    );
  }
}

/// Estado de lista vazia
class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 16,
        ),
      ),
    );
  }
}
