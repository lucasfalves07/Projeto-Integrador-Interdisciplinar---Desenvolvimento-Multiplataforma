import 'package:flutter/material.dart';

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Widget separator;
  final bool showEllipsis;

  const Breadcrumb({
    super.key,
    required this.items,
    this.separator = const Icon(Icons.chevron_right, size: 16),
    this.showEllipsis = false,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    for (int i = 0; i < items.length; i++) {
      children.add(items[i]);

      // Adiciona separador exceto no Ãºltimo
      if (i < items.length - 1) {
        children.add(separator);
      }
    }

    if (showEllipsis) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.more_horiz, size: 18),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class BreadcrumbItem extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isCurrent;

  const BreadcrumbItem({
    super.key,
    required this.text,
    this.onTap,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCurrent
        ? Colors.black
        : Colors.grey.shade600;

    final fontWeight = isCurrent ? FontWeight.w500 : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
          fontSize: 14,
        ),
      ),
    );
  }
}
