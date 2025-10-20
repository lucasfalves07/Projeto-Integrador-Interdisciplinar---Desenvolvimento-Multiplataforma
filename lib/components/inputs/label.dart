import 'package:flutter/material.dart';

class CustomLabel extends StatelessWidget {
  final String text;
  final bool disabled;
  final TextStyle? style;

  const CustomLabel({
    super.key,
    required this.text,
    this.disabled = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style ??
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: disabled ? Colors.grey.withOpacity(0.7) : Colors.black,
          ),
    );
  }
}
