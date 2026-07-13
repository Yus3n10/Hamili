import 'package:flutter_riverpod/flutter_riverpod.dart';

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


final categoriesProvider = FutureProvider<List<AppCategory>>((ref) {
  return ref.read(categoryRepositoryProvider).getCategories();
});


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


      ref.invalidate(budgetsProvider);
      ref.invalidate(budgetTransactionsProvider);
      invalidateAnalytics(ref);
      await future;
    } on OfflineQueuedException {


      final temp = AppTransaction(
        id: -DateTime.now().millisecondsSinceEpoch,
        categoryId: categoryId,
        amount: amount,
        type: type,
        note: note,
        transactionDate: transactionDate,
      );
      state = AsyncData([temp, ...(state.valueOrNull ?? [])]);
      rethrow;
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
      ref.invalidate(budgetTransactionsProvider);
      invalidateAnalytics(ref);
      await future;
    } on OfflineQueuedException {

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
      ref.invalidate(budgetTransactionsProvider);
      invalidateAnalytics(ref);
      await future;
    } on OfflineQueuedException {

      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((t) => t.id != id).toList());
    }
  }
}

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<AppTransaction>>(
  TransactionsNotifier.new,
);
