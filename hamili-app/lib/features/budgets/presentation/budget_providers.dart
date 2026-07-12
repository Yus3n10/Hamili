import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository());

/// Expense transactions for one category, used by the budget detail view
/// to show exactly which transactions make up a budget's spent amount.
/// Keyed by categoryId; the detail page narrows further to the budget's
/// month/year. Fetched independently of the Transactions page's own
/// filter state so opening a budget never depends on what's filtered
/// there. Matches the backend's spent calculation (category + expense).
final budgetTransactionsProvider = FutureProvider.family<List<AppTransaction>, int>((ref, categoryId) {
  ref.watch(sessionIdProvider);
  return ref.read(transactionRepositoryProvider).list(categoryId: categoryId);
});

/// Which month/year the Budgets screen is currently viewing. Defaults to
/// the current month; a future "previous/next month" control just
/// updates this.
class BudgetPeriod {
  final int month;
  final int year;
  const BudgetPeriod({required this.month, required this.year});
}

final budgetPeriodProvider = StateProvider<BudgetPeriod>((ref) {
  final now = DateTime.now();
  return BudgetPeriod(month: now.month, year: now.year);
});

class BudgetsNotifier extends AsyncNotifier<List<AppBudget>> {
  @override
  Future<List<AppBudget>> build() async {
    ref.watch(sessionIdProvider);
    final period = ref.watch(budgetPeriodProvider);
    final repo = ref.read(budgetRepositoryProvider);
    return repo.list(month: period.month, year: period.year);
  }

  Future<void> setBudget({required int categoryId, required double limitAmount}) async {
    final period = ref.read(budgetPeriodProvider);
    final repo = ref.read(budgetRepositoryProvider);
    await repo.setBudget(categoryId: categoryId, month: period.month, year: period.year, limitAmount: limitAmount);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteBudget(int id) async {
    final repo = ref.read(budgetRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<AppBudget>>(BudgetsNotifier.new);
