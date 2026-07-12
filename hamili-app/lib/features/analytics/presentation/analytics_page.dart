import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'analytics_providers.dart';
import 'widgets/category_donut.dart';
import 'widgets/trend_bar_chart.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  void _shiftMonth(WidgetRef ref, int delta) {
    final p = ref.read(analyticsPeriodProvider);
    var m = p.month + delta;
    var y = p.year;
    if (m < 1) {
      m = 12;
      y -= 1;
    }
    if (m > 12) {
      m = 1;
      y += 1;
    }
    ref.read(analyticsPeriodProvider.notifier).state = p.copyWith(month: m, year: y);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);
    final trendAsync = ref.watch(trendProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final monthLabel = DateFormat.yMMMM().format(DateTime(period.year, period.month));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () async {
          // WidgetRef.invalidate here (invalidateAnalytics takes a provider
          // Ref, used by the notifiers); refetch this page's providers.
          ref.invalidate(monthlySummaryProvider);
          ref.invalidate(categoryBreakdownProvider);
          ref.invalidate(trendProvider);
          await ref.read(monthlySummaryProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _shiftMonth(ref, -1), icon: const Icon(Icons.chevron_left)),
                Text(monthLabel, style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => _shiftMonth(ref, 1), icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            summaryAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text("Couldn't load summary."),
              data: (s) => Row(
                children: [
                  _tile(context, 'Income', s.income, AppColors.income),
                  const SizedBox(width: 8),
                  _tile(context, 'Expenses', s.expense, AppColors.expense),
                  const SizedBox(width: 8),
                  _tile(context, 'Net', s.net, s.net >= 0 ? AppColors.income : AppColors.expense),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            breakdownAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text("Couldn't load category breakdown."),
              data: (breakdown) => CategoryDonut(breakdown: breakdown, categories: categories),
            ),
            const SizedBox(height: 24),
            Text('Income vs Expenses', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            trendAsync.when(
              loading: () => const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Text("Couldn't load trend."),
              data: (points) => TrendBarChart(points: points),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, double amount, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
