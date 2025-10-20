import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// ConfiguraÃ§Ã£o do Chart (equivalente ao ChartConfig em React)
class ChartConfig {
  final String label;
  final IconData? icon;
  final Color color;

  ChartConfig({
    required this.label,
    this.icon,
    required this.color,
  });
}

/// Container para envolver o grÃ¡fico (equivalente ao ChartContainer)
class ChartContainer extends StatelessWidget {
  final List<ChartConfig> config;
  final Widget child;

  const ChartContainer({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

/// Tooltip customizado (equivalente ao ChartTooltipContent)
class ChartTooltip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const ChartTooltip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color, margin: const EdgeInsets.only(right: 6)),
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(value.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Legenda customizada (equivalente ao ChartLegendContent)
class ChartLegend extends StatelessWidget {
  final List<ChartConfig> config;

  const ChartLegend({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: config
          .map((c) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: c.color),
                  const SizedBox(width: 4),
                  if (c.icon != null) Icon(c.icon, size: 14, color: c.color),
                  Text(c.label, style: const TextStyle(fontSize: 12)),
                ],
              ))
          .toList(),
    );
  }
}
