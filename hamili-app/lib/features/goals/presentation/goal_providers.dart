import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    await ref.read(goalRepositoryProvider).create(title: title, targetAmount: targetAmount, targetDate: targetDate);
    await _refreshSilently();
  }

  Future<AppSavingsGoal> contribute(int id, double amount) async {
    final updated = await ref.read(goalRepositoryProvider).contribute(id, amount);
    await _refreshSilently();
    return updated;
  }

  Future<void> deleteGoal(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((g) => g.id != id).toList());
    try {
      await ref.read(goalRepositoryProvider).delete(id);
      await _refreshSilently();
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<AppSavingsGoal>>(GoalsNotifier.new);
