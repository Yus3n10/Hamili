import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/analytics_models.dart';

/// Income vs expense per month over the trend window. Two rods per group.
class TrendBarChart extends StatelessWidget {
  const TrendBarChart({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Not enough data yet.')),
      );
    }

    final maxVal = points.expand((p) => [p.income, p.expense]).fold(0.0, (m, v) => v > m ? v : m);
    final maxY = maxVal <= 0 ? 100.0 : maxVal * 1.2;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(enabled: true),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
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
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: points[i].income,
                      color: AppColors.income,
                      width: 7,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    BarChartRodData(
                      toY: points[i].expense,
                      color: AppColors.expense,
                      width: 7,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(AppColors.income, 'Income'),
            const SizedBox(width: 16),
            _legendDot(AppColors.expense, 'Expenses'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
