import 'package:flutter/material.dart';

enum ToastVariant { normal, destructive }

/// Gerenciador global de Toasts (equivalente a ToastProvider + ToastViewport)
class ToastManager {
  static final List<OverlayEntry> _entries = [];

  static void show(
    BuildContext context, {
    required String title,
    String? description,
    ToastVariant variant = ToastVariant.normal,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        title: title,
        description: description,
        variant: variant,
        onAction: onAction,
        actionLabel: actionLabel,
      ),
    );

    overlay.insert(entry);
    _entries.add(entry);

    Future.delayed(duration, () {
      if (_entries.contains(entry)) {
        entry.remove();
        _entries.remove(entry);
      }
    });
  }
}

/// Widget individual do Toast (equivalente ao <Toast /> + subcomponentes)
class _ToastWidget extends StatelessWidget {
  final String title;
  final String? description;
  final ToastVariant variant;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _ToastWidget({
    required this.title,
    this.description,
    this.variant = ToastVariant.normal,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDestructive = variant == ToastVariant.destructive;

    return Positioned(
      bottom: 40,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {},
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                ),
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
                      Text(title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDestructive
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          )),
                      if (description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            description!,
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

                // BotÃ£o de aÃ§Ã£o opcional
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: isDestructive
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                    child: Text(actionLabel!),
                  ),

                // BotÃ£o de fechar
                IconButton(
                  onPressed: () {
                    Navigator.of(context).overlay?.dispose();
                  },
                  icon: Icon(Icons.close,
                      size: 16,
                      color: isDestructive
                          ? Colors.white70
                          : Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
