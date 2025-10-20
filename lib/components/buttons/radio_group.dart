import 'package:flutter/material.dart';

/// Equivalente ao RadioGroup do React
class RadioGroup<T> extends StatelessWidget {
  final T? value;
  final List<RadioGroupItem<T>> items;
  final ValueChanged<T?> onChanged;

  const RadioGroup({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return GestureDetector(
          onTap: () => onChanged(item.value),
          child: Row(
            children: [
              Radio<T>(
                value: item.value,
                groupValue: value,
                onChanged: onChanged,
                activeColor: Theme.of(context).colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              if (item.label != null)
                Text(item.label!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Item de RadioGroup (equivalente ao RadioGroupItem do React)
class RadioGroupItem<T> {
  final T value;
  final String? label;

  RadioGroupItem({
    required this.value,
    this.label,
  });
}
