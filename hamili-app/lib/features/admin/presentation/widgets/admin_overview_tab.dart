import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/admin_models.dart';
import '../admin_providers.dart';
import 'admin_error.dart';

final _compact = NumberFormat.compact();

class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);
    return overview.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [SkeletonCard(), SizedBox(height: 12), SkeletonCard(), SizedBox(height: 12), SkeletonCard()],
      ),
      error: (_, __) => AdminError(onRetry: () => ref.invalidate(adminOverviewProvider)),
      data: (o) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminOverviewProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _Stat(label: 'Testers', value: '${o.testersTotal}', detail: '+${o.new7d} this week'),
                _Stat(label: 'Active today', value: '${o.activeToday}', detail: 'of ${o.testersTotal}'),
                _Stat(label: 'Active 7 days', value: '${o.active7d}', detail: '${o.active30d} in 30 days'),
                _Stat(
                  label: 'Hami tokens 7 days',
                  value: _compact.format(o.hamiTokens7d),
                  detail: '${o.hamiMessages7d} messages',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DailyChart(
              title: 'Active testers per day',
              points: o.daily,
              valueOf: (p) => p.activeTesters,
              color: context.accent,
            ),
            const SizedBox(height: 16),
            _DailyChart(
              title: 'Hami tokens per day',
              points: o.daily,
              valueOf: (p) => p.hamiTokens,
              color: AppColors.chartPalette[1],
            ),
            const SizedBox(height: 16),
            Text(
              o.trackingSince == null
                  ? 'Tracking starts with the next tester visit. Nothing was recorded before this feature shipped.'
                  : 'Tracking since ${DateFormat.yMMMd().format(o.trackingSince!)}. Nothing was recorded before then.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(detail, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.title, required this.points, required this.valueOf, required this.color});

  final String title;
  final List<AdminDayPoint> points;
  final int Function(AdminDayPoint) valueOf;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final peak = points.fold<int>(0, (m, p) => valueOf(p) > m ? valueOf(p) : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: peak == 0 ? 1 : peak * 1.2,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        '${DateFormat.MMMd().format(points[group.x].day)}\n${_compact.format(rod.toY)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value != value.roundToDouble()) return const SizedBox.shrink();
                          return Text(_compact.format(value), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          // A label every week keeps 30 bars readable on a phone.
                          if (i < 0 || i >= points.length || (points.length - 1 - i) % 7 != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('d/M').format(points[i].day), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < points.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: valueOf(points[i]).toDouble(),
                          color: color,
                          width: 5,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ]),
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
