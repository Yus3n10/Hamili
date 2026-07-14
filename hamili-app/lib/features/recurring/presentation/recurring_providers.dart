import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_queue.dart';
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
    try {
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
    } on OfflineQueuedException {
      final temp = RecurringItem(
        id: -DateTime.now().millisecondsSinceEpoch,
        type: type,
        name: name,
        amount: amount,
        categoryId: categoryId,
        frequency: frequency,
        nextDueDate: nextDueDate,
        active: true,
      );
      state = AsyncData([...(state.valueOrNull ?? []), temp]);
    }
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
    try {
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
    } on OfflineQueuedException {
      state = AsyncData(_patch(id, name: name, amount: amount, categoryId: categoryId, frequency: frequency, nextDueDate: nextDueDate, active: active));
    }
  }

  Future<void> toggleActive(int id, bool active) async {
    try {
      await ref.read(recurringRepositoryProvider).update(id, active: active);
      ref.invalidateSelf();
      await future;
    } on OfflineQueuedException {
      state = AsyncData(_patch(id, active: active));
    }
  }

  Future<void> deleteItem(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != id).toList());
    try {
      await ref.read(recurringRepositoryProvider).delete(id);
      ref.invalidateSelf();
      await future;
    } on OfflineQueuedException {
      return;
    } catch (_) {
      ref.invalidateSelf();
    }
  }

  List<RecurringItem> _patch(
    int id, {
    String? name,
    double? amount,
    int? categoryId,
    String? frequency,
    DateTime? nextDueDate,
    bool? active,
  }) {
    return [
      for (final r in (state.valueOrNull ?? []))
        if (r.id == id)
          RecurringItem(
            id: r.id,
            type: r.type,
            name: name ?? r.name,
            amount: amount ?? r.amount,
            categoryId: categoryId ?? r.categoryId,
            frequency: frequency ?? r.frequency,
            nextDueDate: nextDueDate ?? r.nextDueDate,
            active: active ?? r.active,
          )
        else
          r,
    ];
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
