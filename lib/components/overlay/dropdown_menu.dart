import 'package:flutter/material.dart';

class CustomDropdownMenu extends StatefulWidget {
  final Widget trigger;
  final List<CustomDropdownMenuEntry> items;

  const CustomDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
  });

  @override
  State<CustomDropdownMenu> createState() => _CustomDropdownMenuState();
}

class _CustomDropdownMenuState extends State<CustomDropdownMenu> {
  void _showMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset position = button.localToGlobal(Offset.zero, ancestor: overlay);
    final RelativeRect rect = RelativeRect.fromLTRB(
      position.dx,
      position.dy + button.size.height,
      overlay.size.width - position.dx - button.size.width,
      overlay.size.height - position.dy,
    );

    final result = await showMenu(
      context: context,
      position: rect,
      items: widget.items.map((e) => e.toPopupMenuItem()).toList(),
    );

    if (result != null) {
      result();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: widget.trigger,
    );
  }
}

class CustomDropdownMenuEntry {
  final String label;
  final VoidCallback? onTap;
  final bool checked;
  final bool isRadio;
  final bool enabled;
  final Widget? icon;
  final Widget? trailing;

  CustomDropdownMenuEntry({
    required this.label,
    this.onTap,
    this.checked = false,
    this.isRadio = false,
    this.enabled = true,
    this.icon,
    this.trailing,
  });

  PopupMenuItem<VoidCallback> toPopupMenuItem() {
    return PopupMenuItem<VoidCallback>(
      enabled: enabled,
      value: onTap,
      child: Row(
        children: [
          if (isRadio)
            Icon(
              checked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
            )
          else if (checked)
            const Icon(Icons.check, size: 16),
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
