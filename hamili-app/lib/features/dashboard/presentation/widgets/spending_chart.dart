import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/transaction.dart';

enum _Range { week, month, year }

class _Bucket {
  const _Bucket(this.label, this.value);
  final String label;
  final double value;
}


class SpendingChart extends StatefulWidget {
  const SpendingChart({super.key, required this.transactions});

  final List<AppTransaction> transactions;

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  _Range _range = _Range.month;

  List<_Bucket> _buckets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenses = widget.transactions.where((t) => t.type == 'expense');

    double sumBetween(DateTime start, DateTime end) => expenses
        .where((t) {
          final d = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
          return !d.isBefore(start) && !d.isAfter(end);
        })
        .fold(0.0, (s, t) => s + t.amount);

    switch (_range) {
      case _Range.week:
        const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        return [
          for (int i = 6; i >= 0; i--)
            () {
              final day = today.subtract(Duration(days: i));
              return _Bucket(wd[day.weekday - 1], sumBetween(day, day));
            }()
        ];
      case _Range.month:
        return [
          for (int i = 3; i >= 0; i--)
            () {
              final end = today.subtract(Duration(days: 7 * i));
              final start = end.subtract(const Duration(days: 6));
              return _Bucket('${start.day}/${start.month}', sumBetween(start, end));
            }()
        ];
      case _Range.year:
        const mn = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
        return [
          for (int i = 11; i >= 0; i--)
            () {
              final m = DateTime(now.year, now.month - i, 1);
              final start = DateTime(m.year, m.month, 1);
              final end = DateTime(m.year, m.month + 1, 0);
              return _Bucket(mn[m.month - 1], sumBetween(start, end));
            }()
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets();
    final maxV = buckets.fold(0.0, (m, b) => b.value > m ? b.value : m);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.25;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Spending', style: Theme.of(context).textTheme.titleMedium),
                SegmentedButton<_Range>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: _Range.week, label: Text('W')),
                    ButtonSegment(value: _Range.month, label: Text('M')),
                    ButtonSegment(value: _Range.year, label: Text('Y')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        CurrencyFormatter.format(rod.toY),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(buckets[i].label, style: TextStyle(color: muted, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[i].value,
                            width: 14,
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [AppColors.primaryDark, AppColors.primary],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
