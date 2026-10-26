import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/budget_alert_tracker.dart';
import '../domain/hami_reaction.dart';
import 'hami_controller.dart';

/// Keeps Hami listening to the app's own budget and balance data. Watched by
/// the reaction overlay, so it lives as long as the signed-in app does.
final hamiEventBridgeProvider = Provider<void>((ref) {
  final tracker = ref.watch(budgetAlertTrackerProvider);

  ref.listen<AsyncValue<List<AppBudget>>>(budgetsProvider, (_, next) {
    final budgets = next.valueOrNull;
    if (budgets == null) return;
    final alert = tracker.update(budgets);
    if (alert == null) return;
    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    final match = categories.where((c) => c.id == alert.budget.categoryId);
    final name = match.isNotEmpty ? match.first.name : 'A budget';
    ref.read(hamiControllerProvider.notifier).play(alert.reaction, caption: budgetCaption(alert, name));
  }, fireImmediately: true);

  ref.listen<AsyncValue<AnalyticsSummary>>(dashboardSummaryProvider, (_, next) {
    final net = next.valueOrNull?.net;
    if (net == null || !tracker.updateBalance(net)) return;
    ref.read(hamiControllerProvider.notifier).play(HamiReaction.overBudget, caption: 'Your balance is below zero');
  }, fireImmediately: true);
});

String budgetCaption(BudgetAlert alert, String categoryName) {
  final b = alert.budget;
  return switch (alert.reaction) {
    HamiReaction.overBudget =>
      '$categoryName is ${CurrencyFormatter.format(b.spentAmount - b.limitAmount)} over budget!',
    HamiReaction.warnSpending => '$categoryName is at ${b.percentageUsed.round()}% of its budget!',
    _ => '$categoryName is at ${b.percentageUsed.round()}% of its budget',
  };
}

/// Hami's reaction to a successful money event. Call only after the server
/// confirmed the write; failed, cancelled or offline-queued writes stay quiet.
void hamiOnIncome(Ref ref, double amount) => ref
    .read(hamiControllerProvider.notifier)
    .play(HamiReaction.celebrateIncome, caption: '${CurrencyFormatter.format(amount)} income recorded');

void hamiOnSavings(Ref ref, double amount, String goalTitle) => ref
    .read(hamiControllerProvider.notifier)
    .play(HamiReaction.celebrateSavings, caption: '${CurrencyFormatter.format(amount)} saved toward $goalTitle');

void hamiOnSpending(Ref ref) => ref.read(budgetAlertTrackerProvider).expectSpending();
