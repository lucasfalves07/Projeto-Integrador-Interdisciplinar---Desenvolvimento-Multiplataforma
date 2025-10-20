import 'package:flutter/material.dart';

enum ToastVariant { normal, destructive }

class ToastEntry {
  final String id;
  final String? title;
  final String? description;
  final ToastVariant variant;
  final Widget? action;

  ToastEntry({
    required this.id,
    this.title,
    this.description,
    this.variant = ToastVariant.normal,
    this.action,
  });
}

class ToastController extends ChangeNotifier {
  final List<ToastEntry> _toasts = [];
  List<ToastEntry> get toasts => List.unmodifiable(_toasts);

  void show(ToastEntry toast) {
    _toasts.add(toast);
    notifyListeners();

    Future.delayed(const Duration(seconds: 3), () {
      dismiss(toast.id);
    });
  }

  void dismiss(String id) {
    _toasts.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}

/// Provider global (equivalente ao ToastProvider)
class Toaster extends StatefulWidget {
  final Widget child;
  final ToastController controller;

  const Toaster({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<Toaster> createState() => _ToasterState();
}

class _ToasterState extends State<Toaster> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 40,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: widget.controller.toasts.map((toast) {
              return _ToastWidget(
                entry: toast,
                onClose: () => widget.controller.dismiss(toast.id),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ToastWidget extends StatelessWidget {
  final ToastEntry entry;
  final VoidCallback onClose;

  const _ToastWidget({required this.entry, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDestructive = entry.variant == ToastVariant.destructive;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: isDestructive
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDestructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).dividerColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ConteÃºdo principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.title != null)
                  Text(
                    entry.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (entry.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDestructive
                            ? Colors.white70
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // AÃ§Ã£o opcional
          if (entry.action != null) entry.action!,

          // BotÃ£o de fechar
          IconButton(
            icon: Icon(Icons.close,
                size: 16,
                color: isDestructive
                    ? Colors.white70
                    : Theme.of(context).hintColor),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
