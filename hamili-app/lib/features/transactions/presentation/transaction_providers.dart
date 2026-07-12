import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../data/category_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) => TransactionRepository());
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => CategoryRepository());

/// All categories, loaded once and cached — every picker in the app reads
/// this instead of hitting the network repeatedly.
final categoriesProvider = FutureProvider<List<AppCategory>>((ref) {
  return ref.read(categoryRepositoryProvider).getCategories();
});

/// Search/filter state driving the transactions list. Kept separate from
/// the list notifier so changing a filter doesn't require rebuilding the
/// whole async-state machine — it just triggers a refetch.
class TransactionFilter {
  final int? categoryId;
  final String? search;
  const TransactionFilter({this.categoryId, this.search});

  TransactionFilter copyWith({int? categoryId, String? search, bool clearCategory = false}) {
    return TransactionFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      search: search ?? this.search,
    );
  }
}

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) => const TransactionFilter());

/// The transaction list itself. Watches the filter provider so any filter
/// change automatically triggers a refetch through AsyncNotifier's
/// dependency tracking.
class TransactionsNotifier extends AsyncNotifier<List<AppTransaction>> {
  @override
  Future<List<AppTransaction>> build() async {
    ref.watch(sessionIdProvider);
    final filter = ref.watch(transactionFilterProvider);
    final repo = ref.read(transactionRepositoryProvider);
    return repo.list(categoryId: filter.categoryId, search: filter.search);
  }

  Future<void> addTransaction({
    required int categoryId,
    required double amount,
    required String type,
    required DateTime transactionDate,
    String? note,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.create(
      categoryId: categoryId,
      amount: amount,
      type: type,
      transactionDate: transactionDate,
      note: note,
    );
    ref.invalidateSelf();
    // Budgets compute spent_amount live from transactions, so a new
    // expense here means every budget's usage figure is now stale until
    // this refetches.
    ref.invalidate(budgetsProvider);
    invalidateAnalytics(ref);
    await future;
  }

  Future<void> editTransaction(
    int id, {
    int? categoryId,
    double? amount,
    String? note,
    DateTime? transactionDate,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.update(id, categoryId: categoryId, amount: amount, note: note, transactionDate: transactionDate);
    ref.invalidateSelf();
    ref.invalidate(budgetsProvider);
    invalidateAnalytics(ref);
    await future;
  }

  Future<void> deleteTransaction(int id) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
    ref.invalidate(budgetsProvider);
    invalidateAnalytics(ref);
    await future;
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<AppTransaction>>(
  TransactionsNotifier.new,
);
