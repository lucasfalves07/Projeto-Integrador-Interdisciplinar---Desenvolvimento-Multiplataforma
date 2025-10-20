import 'package:flutter/material.dart';

/// Menu de contexto customizado (equivalente ao ContextMenu do React)
class ContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuItem> items;

  const ContextMenu({
    super.key,
    required this.position,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 4,
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        ),
      ],
    );
  }
}

/// Item genÃ©rico do menu (equivalente ao ContextMenuItem)
class ContextMenuItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool disabled;

  const ContextMenuItem({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (icon != null) Icon(icon, size: 18),
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: disabled ? Colors.grey : Theme.of(context).textTheme.bodyMedium?.color,
            )),
          ],
        ),
      ),
    );
  }
}

/// Item com checkbox (equivalente ao ContextMenuCheckboxItem)
class ContextMenuCheckboxItem extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const ContextMenuCheckboxItem({
    super.key,
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onChanged(!checked),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Item com radio button (equivalente ao ContextMenuRadioItem)
class ContextMenuRadioItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const ContextMenuRadioItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onSelected(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Separador (equivalente ao ContextMenuSeparator)
class ContextMenuSeparator extends StatelessWidget {
  const ContextMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Colors.grey.shade300);
  }
}
