import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget>? actions;
  final Widget? child;

  const CustomDialog({
    super.key,
    this.title,
    this.description,
    this.actions,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
              if (child != null) ...[
                const SizedBox(height: 12),
                child!,
              ],
              if (actions != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void showCustomDialog({
  required BuildContext context,
  String? title,
  String? description,
  Widget? child,
  List<Widget>? actions,
}) {
  showDialog(
    context: context,
    builder: (ctx) => CustomDialog(
      title: title,
      description: description,
      child: child,
      actions: actions,
    ),
  );
}
