import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_queue.dart';
import '../../../core/session/session_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) => BudgetRepository());


final budgetTransactionsProvider = FutureProvider.family<List<AppTransaction>, int>((ref, categoryId) {
  ref.watch(sessionIdProvider);
  return ref.read(transactionRepositoryProvider).list(categoryId: categoryId);
});


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
    final cached = await repo.cached(month: period.month, year: period.year);
    if (cached != null) {
      Future.microtask(_refreshSilently);
      return cached;
    }
    return repo.list(month: period.month, year: period.year);
  }

  Future<void> _refreshSilently() async {
    final period = ref.read(budgetPeriodProvider);
    final repo = ref.read(budgetRepositoryProvider);
    try {
      state = AsyncData(await repo.list(month: period.month, year: period.year));
    } catch (_) {}
  }

  Future<void> setBudget({required int categoryId, required double limitAmount}) async {
    final period = ref.read(budgetPeriodProvider);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .setBudget(categoryId: categoryId, month: period.month, year: period.year, limitAmount: limitAmount);
      await _refreshSilently();
    } on OfflineQueuedException {
      final temp = AppBudget(
        id: -DateTime.now().millisecondsSinceEpoch,
        categoryId: categoryId,
        month: period.month,
        year: period.year,
        limitAmount: limitAmount,
        spentAmount: 0,
        remainingAmount: limitAmount,
        percentageUsed: 0,
      );
      final current = (state.valueOrNull ?? []).where((b) => b.categoryId != categoryId).toList();
      state = AsyncData([...current, temp]);
    }
  }

  Future<void> deleteBudget(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((b) => b.id != id).toList());
    try {
      await ref.read(budgetRepositoryProvider).delete(id);
      await _refreshSilently();
    } on OfflineQueuedException {
      return;
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<AppBudget>>(BudgetsNotifier.new);
