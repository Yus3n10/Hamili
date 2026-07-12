import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/piggy_events.dart';
import '../../../core/network/offline_queue.dart';
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
    try {
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
      if (type == 'income') ref.read(piggyCoinFlipProvider.notifier).state++; // Hami celebrates income
      await future;
    } on OfflineQueuedException {
      // Queued offline — show it immediately with a temporary negative id;
      // the real row replaces it when the queue syncs and the list refetches.
      final temp = AppTransaction(
        id: -DateTime.now().millisecondsSinceEpoch,
        categoryId: categoryId,
        amount: amount,
        type: type,
        note: note,
        transactionDate: transactionDate,
      );
      state = AsyncData([temp, ...(state.valueOrNull ?? [])]);
      rethrow; // let the form surface a "saved offline" message
    }
  }

  Future<void> editTransaction(
    int id, {
    int? categoryId,
    double? amount,
    String? note,
    DateTime? transactionDate,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    try {
      await repo.update(id, categoryId: categoryId, amount: amount, note: note, transactionDate: transactionDate);
      ref.invalidateSelf();
      ref.invalidate(budgetsProvider);
      invalidateAnalytics(ref);
      await future;
    } on OfflineQueuedException {
      // Optimistic local edit until the queued update syncs.
      final current = state.valueOrNull ?? [];
      state = AsyncData([
        for (final t in current)
          if (t.id == id)
            AppTransaction(
              id: id,
              categoryId: categoryId ?? t.categoryId,
              amount: amount ?? t.amount,
              type: t.type,
              note: note ?? t.note,
              transactionDate: transactionDate ?? t.transactionDate,
            )
          else
            t,
      ]);
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    final repo = ref.read(transactionRepositoryProvider);
    try {
      await repo.delete(id);
      ref.invalidateSelf();
      ref.invalidate(budgetsProvider);
      invalidateAnalytics(ref);
      await future;
    } on OfflineQueuedException {
      // Keep it removed optimistically; the queued delete syncs later.
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((t) => t.id != id).toList());
    }
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<AppTransaction>>(
  TransactionsNotifier.new,
);
