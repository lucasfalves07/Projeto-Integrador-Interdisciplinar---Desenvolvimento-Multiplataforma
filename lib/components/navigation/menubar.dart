import 'package:flutter/material.dart';

class CustomMenubar extends StatelessWidget {
  final List<Widget> items;

  const CustomMenubar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: items,
      ),
    );
  }
}

class MenubarItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool inset;

  const MenubarItem({
    super.key,
    required this.label,
    this.onTap,
    this.disabled = false,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: inset ? 16 : 8,
          vertical: 6,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: disabled
                ? Colors.grey.withOpacity(0.6)
                : Theme.of(context).colorScheme.onBackground,
          ),
        ),
      ),
    );
  }
}

class MenubarCheckboxItem extends StatefulWidget {
  final String label;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  const MenubarCheckboxItem({
    super.key,
    required this.label,
    this.initialValue = false,
    this.onChanged,
  });

  @override
  State<MenubarCheckboxItem> createState() => _MenubarCheckboxItemState();
}

class _MenubarCheckboxItemState extends State<MenubarCheckboxItem> {
  late bool checked;

  @override
  void initState() {
    super.initState();
    checked = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: (value) {
        if (value != null) {
          setState(() => checked = value);
          widget.onChanged?.call(value);
        }
      },
      title: Text(widget.label, style: const TextStyle(fontSize: 14)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
    );
  }
}

class MenubarRadioGroup<T> extends StatelessWidget {
  final T groupValue;
  final ValueChanged<T?> onChanged;
  final List<MenubarRadioItem<T>> items;

  const MenubarRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) {
        return RadioListTile<T>(
          value: item.value,
          groupValue: groupValue,
          onChanged: onChanged,
          title: Text(item.label, style: const TextStyle(fontSize: 14)),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        );
      }).toList(),
    );
  }
}

class MenubarRadioItem<T> {
  final T value;
  final String label;

  MenubarRadioItem({required this.value, required this.label});
}

class MenubarLabel extends StatelessWidget {
  final String text;

  const MenubarLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class MenubarSeparator extends StatelessWidget {
  const MenubarSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1);
  }
}

class MenubarShortcut extends StatelessWidget {
  final String text;

  const MenubarShortcut({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }
}
