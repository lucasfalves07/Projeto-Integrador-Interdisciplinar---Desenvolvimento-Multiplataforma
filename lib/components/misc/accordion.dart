import 'package:flutter/material.dart';

/// Accordion raiz - sÃ³ um wrapper para lista de items
class Accordion extends StatelessWidget {
  final List<Widget> children;

  const Accordion({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children,
    );
  }
}

/// AccordionItem equivale ao Item do React
class AccordionItem extends StatelessWidget {
  final String title;
  final Widget content;
  final bool initiallyExpanded;

  const AccordionItem({
    super.key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.expand_more), // equivale ao ChevronDown
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: content,
        ),
      ],
    );
  }
}
