import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_models.dart';


class NetBalanceLineChart extends StatelessWidget {
  const NetBalanceLineChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Not enough data yet.')),
      );
    }

    final cumulative = <double>[];
    var running = 0.0;
    for (final p in points) {
      running += p.income - p.expense;
      cumulative.add(running);
    }

    final minVal = cumulative.reduce((a, b) => a < b ? a : b);
    final maxVal = cumulative.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal).abs();
    final pad = span == 0 ? (maxVal.abs() == 0 ? 100.0 : maxVal.abs() * 0.2) : span * 0.2;
    final minY = (minVal < 0 ? minVal : 0.0) - pad;
    final maxY = (maxVal > 0 ? maxVal : 0.0) + pad;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,


                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox.shrink();
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  final label = DateFormat.MMM().format(DateTime(points[i].year, points[i].month));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < cumulative.length; i++) FlSpot(i.toDouble(), cumulative[i])],
              isCurved: true,
              color: context.accent,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: context.accent.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}
