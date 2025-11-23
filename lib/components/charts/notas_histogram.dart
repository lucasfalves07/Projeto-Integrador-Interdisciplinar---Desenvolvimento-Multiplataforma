import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class NotasHistogram extends StatelessWidget {
  final Map<String, int> buckets; // keys: 0-2,2-4,4-6,6-8,8-10
  final String title;

  const NotasHistogram({super.key, required this.buckets, this.title = 'Distribuição de notas'});

  List<BarChartGroupData> _bars(BuildContext context) {
    final order = ['0-2', '2-4', '4-6', '6-8', '8-10'];
    final maxV = buckets.values.fold<int>(0, (a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    return [
      for (var i = 0; i < order.length; i++)
        BarChartGroupData(x: i, barRods: [
          BarChartRodData(
            toY: (buckets[order[i]] ?? 0).toDouble(),
            color: color,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          )
        ])
    ];
  }

  @override
  Widget build(BuildContext context) {
    final order = ['0-2', '2-4', '4-6', '6-8', '8-10'];
    final maxV = (buckets.values.isEmpty ? 0 : (buckets.values.reduce((a, b) => a > b ? a : b)));

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: _bars(context),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= order.length) return const SizedBox.shrink();
                          return Text(order[idx], style: const TextStyle(fontSize: 11));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  maxY: (maxV + 1).toDouble(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


