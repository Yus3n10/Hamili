import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_item.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) => RecurringRepository());

class RecurringNotifier extends AsyncNotifier<List<RecurringItem>> {
  @override
  Future<List<RecurringItem>> build() async {
    ref.watch(sessionIdProvider);
    return ref.read(recurringRepositoryProvider).list();
  }


  void _invalidateDerived() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(budgetsProvider);
    invalidateAnalytics(ref);
  }

  Future<void> addItem({
    required String type,
    required String name,
    required double amount,
    required int categoryId,
    required String frequency,
    required DateTime nextDueDate,
  }) async {
    await ref.read(recurringRepositoryProvider).create(
          type: type,
          name: name,
          amount: amount,
          categoryId: categoryId,
          frequency: frequency,
          nextDueDate: nextDueDate,
        );
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
  }

  Future<void> editItem(
    int id, {
    String? name,
    double? amount,
    int? categoryId,
    String? frequency,
    DateTime? nextDueDate,
    bool? active,
  }) async {
    await ref.read(recurringRepositoryProvider).update(
          id,
          name: name,
          amount: amount,
          categoryId: categoryId,
          frequency: frequency,
          nextDueDate: nextDueDate,
          active: active,
        );
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
  }

  Future<void> toggleActive(int id, bool active) async {
    await ref.read(recurringRepositoryProvider).update(id, active: active);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteItem(int id) async {
    await ref.read(recurringRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }


  Future<int> runDue() async {
    final promoted = await ref.read(recurringRepositoryProvider).runDue();
    ref.invalidateSelf();
    _invalidateDerived();
    await future;
    return promoted;
  }
}

final recurringProvider = AsyncNotifierProvider<RecurringNotifier, List<RecurringItem>>(
  RecurringNotifier.new,
);
