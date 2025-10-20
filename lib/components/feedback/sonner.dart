import 'package:flutter/material.dart';

/// Enum para tema (equivalente ao useTheme do Next)
enum ToasterTheme { light, dark, system }

/// ConfiguraÃ§Ã£o global do Toaster
class Toaster extends StatefulWidget {
  final ToasterTheme theme;
  final Widget child;

  const Toaster({
    super.key,
    required this.child,
    this.theme = ToasterTheme.system,
  });

  @override
  State<Toaster> createState() => _ToasterState();

  /// MÃ©todo estÃ¡tico para disparar notificaÃ§Ãµes
  static void showToast(
    BuildContext context, {
    required String message,
    String? description,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: _ToastWidget(
          message: message,
          description: description,
          backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
          textColor: textColor ?? Theme.of(context).colorScheme.onSurface,
          duration: duration,
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(duration, () => entry.remove());
  }
}

class _ToasterState extends State<Toaster> {
  @override
  Widget build(BuildContext context) {
    ThemeData themeData;

    switch (widget.theme) {
      case ToasterTheme.dark:
        themeData = ThemeData.dark();
        break;
      case ToasterTheme.light:
        themeData = ThemeData.light();
        break;
      case ToasterTheme.system:
      default:
        themeData = Theme.of(context);
    }

    return Theme(data: themeData, child: widget.child);
  }
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final String? description;
  final Color backgroundColor;
  final Color textColor;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    this.description,
    required this.backgroundColor,
    required this.textColor,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(description!,
                      style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
