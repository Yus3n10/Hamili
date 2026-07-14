import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_queue.dart';
import '../../../core/session/session_provider.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) => GoalRepository());

class GoalsNotifier extends AsyncNotifier<List<AppSavingsGoal>> {
  @override
  Future<List<AppSavingsGoal>> build() async {
    ref.watch(sessionIdProvider);
    final repo = ref.read(goalRepositoryProvider);
    final cached = await repo.cached();
    if (cached != null) {
      Future.microtask(_refreshSilently);
      return cached;
    }
    return repo.list();
  }

  Future<void> _refreshSilently() async {
    try {
      state = AsyncData(await ref.read(goalRepositoryProvider).list());
    } catch (_) {}
  }

  Future<void> addGoal({required String title, required double targetAmount, DateTime? targetDate}) async {
    try {
      await ref.read(goalRepositoryProvider).create(title: title, targetAmount: targetAmount, targetDate: targetDate);
      await _refreshSilently();
    } on OfflineQueuedException {
      final temp = AppSavingsGoal(
        id: -DateTime.now().millisecondsSinceEpoch,
        title: title,
        targetAmount: targetAmount,
        currentAmount: 0,
        remainingAmount: targetAmount,
        progressPercentage: 0,
        status: 'active',
        targetDate: targetDate,
      );
      state = AsyncData([...(state.valueOrNull ?? []), temp]);
    }
  }

  Future<AppSavingsGoal> contribute(int id, double amount) async {
    try {
      final updated = await ref.read(goalRepositoryProvider).contribute(id, amount);
      await _refreshSilently();
      return updated;
    } on OfflineQueuedException {
      final current = state.valueOrNull ?? [];
      final goal = current.firstWhere((g) => g.id == id);
      final newAmount = goal.currentAmount + amount;
      final completed = newAmount >= goal.targetAmount;
      final updated = AppSavingsGoal(
        id: goal.id,
        title: goal.title,
        targetAmount: goal.targetAmount,
        currentAmount: newAmount,
        remainingAmount: completed ? 0.0 : goal.targetAmount - newAmount,
        progressPercentage: completed ? 100.0 : (newAmount / goal.targetAmount) * 100,
        status: completed ? 'completed' : goal.status,
        targetDate: goal.targetDate,
        estimatedCompletionDate: goal.estimatedCompletionDate,
      );
      state = AsyncData([for (final g in current) if (g.id == id) updated else g]);
      return updated;
    }
  }

  Future<void> deleteGoal(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((g) => g.id != id).toList());
    try {
      await ref.read(goalRepositoryProvider).delete(id);
      await _refreshSilently();
    } on OfflineQueuedException {
      return;
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<AppSavingsGoal>>(GoalsNotifier.new);
