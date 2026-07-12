import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => AnalyticsRepository());

class AnalyticsPeriod {
  final int month;
  final int year;
  const AnalyticsPeriod({required this.month, required this.year});

  AnalyticsPeriod copyWith({int? month, int? year}) =>
      AnalyticsPeriod(month: month ?? this.month, year: year ?? this.year);
}

/// Month the Analytics page is viewing (default: current month). The
/// dashboard summary ignores this and is always all-time.
final analyticsPeriodProvider = StateProvider<AnalyticsPeriod>((ref) {
  final now = DateTime.now();
  return AnalyticsPeriod(month: now.month, year: now.year);
});

/// All-time summary for the dashboard's balance/income/expense.
final dashboardSummaryProvider = FutureProvider<AnalyticsSummary>((ref) {
  ref.watch(sessionIdProvider);
  return ref.read(analyticsRepositoryProvider).summary();
});

final monthlySummaryProvider = FutureProvider<AnalyticsSummary>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).summary(month: p.month, year: p.year);
});

final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdown>>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).byCategory(month: p.month, year: p.year);
});

final trendProvider = FutureProvider<List<TrendPoint>>((ref) {
  ref.watch(sessionIdProvider);
  final p = ref.watch(analyticsPeriodProvider);
  return ref.read(analyticsRepositoryProvider).trend(month: p.month, year: p.year);
});

/// Called by any notifier that changes transactions (directly or via
/// recurring promotion) so the dashboard totals and every chart refetch.
void invalidateAnalytics(Ref ref) {
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(monthlySummaryProvider);
  ref.invalidate(categoryBreakdownProvider);
  ref.invalidate(trendProvider);
}
