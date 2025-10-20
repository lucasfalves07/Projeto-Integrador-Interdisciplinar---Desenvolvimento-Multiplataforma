import 'package:flutter/material.dart';

enum AlertVariant { normal, destructive }

class Alert extends StatelessWidget {
  final AlertVariant variant;
  final Widget? title;
  final Widget? description;

  const Alert({
    super.key,
    this.variant = AlertVariant.normal,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    Color textColor;

    switch (variant) {
      case AlertVariant.destructive:
        borderColor = Colors.red.withOpacity(0.5);
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        break;
      case AlertVariant.normal:
      default:
        borderColor = Colors.grey.shade300;
        bgColor = Colors.white;
        textColor = Colors.black87;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              child: title!,
            ),
          if (description != null) ...[
            const SizedBox(height: 4),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
              child: description!,
            ),
          ],
        ],
      ),
    );
  }
}

class AlertTitle extends StatelessWidget {
  final String text;

  const AlertTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}

class AlertDescription extends StatelessWidget {
  final String text;

  const AlertDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
