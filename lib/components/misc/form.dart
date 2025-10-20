import 'package:flutter/material.dart';

/// Container for managing form state manually (replacement for react-hook-form).
class CustomForm extends InheritedWidget {
  final Map<String, dynamic> values;
  final Function(String, dynamic) onChanged;

  const CustomForm({
    super.key,
    required this.values,
    required this.onChanged,
    required Widget child,
  }) : super(child: child);

  static CustomForm? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CustomForm>();
  }

  @override
  bool updateShouldNotify(CustomForm oldWidget) {
    return values != oldWidget.values;
  }
}

class FormItem extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const FormItem({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: child,
    );
  }
}

class FormLabel extends StatelessWidget {
  final String text;
  final bool hasError;

  const FormLabel({super.key, required this.text, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: hasError ? Colors.red : Colors.black,
      ),
    );
  }
}

class FormControl extends StatelessWidget {
  final String name;
  final Widget child;

  const FormControl({super.key, required this.name, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class FormDescription extends StatelessWidget {
  final String text;

  const FormDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}

class FormMessage extends StatelessWidget {
  final String? message;

  const FormMessage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Text(
      message!,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.red,
      ),
    );
  }
}
