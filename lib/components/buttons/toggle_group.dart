import 'package:flutter/material.dart';

enum ToggleVariant { normal, outlined, filled }
enum ToggleSize { small, medium, large }

class ToggleGroup extends StatefulWidget {
  final List<String> values;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;
  final ToggleVariant variant;
  final ToggleSize size;
  final bool multiple; // true = multi-select, false = single-select

  const ToggleGroup({
    super.key,
    required this.values,
    required this.selectedValues,
    required this.onChanged,
    this.variant = ToggleVariant.normal,
    this.size = ToggleSize.medium,
    this.multiple = false,
  });

  @override
  State<ToggleGroup> createState() => _ToggleGroupState();
}

class _ToggleGroupState extends State<ToggleGroup> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedValues);
  }

  void _toggle(String value) {
    setState(() {
      if (widget.multiple) {
        if (_selected.contains(value)) {
          _selected.remove(value);
        } else {
          _selected.add(value);
        }
      } else {
        _selected = [value];
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: widget.values.map((val) {
        final isSelected = _selected.contains(val);
        return ToggleGroupItem(
          label: val,
          selected: isSelected,
          onTap: () => _toggle(val),
          variant: widget.variant,
          size: widget.size,
        );
      }).toList(),
    );
  }
}

class ToggleGroupItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ToggleVariant variant;
  final ToggleSize size;

  const ToggleGroupItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.variant = ToggleVariant.normal,
    this.size = ToggleSize.medium,
  });

  double _getPadding() {
    switch (size) {
      case ToggleSize.small:
        return 6;
      case ToggleSize.large:
        return 14;
      case ToggleSize.medium:
      default:
        return 10;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    switch (size) {
      case ToggleSize.small:
        return Theme.of(context).textTheme.bodySmall!;
      case ToggleSize.large:
        return Theme.of(context).textTheme.titleMedium!;
      case ToggleSize.medium:
      default:
        return Theme.of(context).textTheme.bodyMedium!;
    }
  }

  BoxDecoration _getDecoration(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (variant) {
      case ToggleVariant.outlined:
        return BoxDecoration(
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(6),
          color: selected ? colorScheme.primary.withOpacity(0.1) : null,
        );
      case ToggleVariant.filled:
        return BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(6),
        );
      case ToggleVariant.normal:
      default:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? colorScheme.primary.withOpacity(0.2) : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _getPadding(),
          vertical: _getPadding() / 2,
        ),
        decoration: _getDecoration(context),
        child: Text(
          label,
          style: _getTextStyle(context).copyWith(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
