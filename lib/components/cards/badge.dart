import 'package:flutter/material.dart';

enum BadgeVariant { 
  normal, 
  secondary, 
  destructive, 
  outline 
}

class Badge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;

  const Badge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.normal,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case BadgeVariant.secondary:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black87;
        borderColor = Colors.transparent;
        break;
      case BadgeVariant.destructive:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        borderColor = Colors.transparent;
        break;
      case BadgeVariant.outline:
        bgColor = Colors.transparent;
        textColor = Colors.black87;
        borderColor = Colors.black26;
        break;
      case BadgeVariant.normal:
      default:
        bgColor = Colors.blue.shade600;
        textColor = Colors.white;
        borderColor = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
