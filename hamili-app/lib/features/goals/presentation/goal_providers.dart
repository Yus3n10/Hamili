import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/piggy_events.dart';
import '../../../core/session/session_provider.dart';
import '../data/goal_repository.dart';
import '../domain/goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) => GoalRepository());

class GoalsNotifier extends AsyncNotifier<List<AppSavingsGoal>> {
  @override
  Future<List<AppSavingsGoal>> build() async {
    ref.watch(sessionIdProvider);
    return ref.read(goalRepositoryProvider).list();
  }

  Future<void> addGoal({required String title, required double targetAmount, DateTime? targetDate}) async {
    final repo = ref.read(goalRepositoryProvider);
    await repo.create(title: title, targetAmount: targetAmount, targetDate: targetDate);
    ref.invalidateSelf();
    await future;
  }

  /// Returns the updated goal so the UI can check `isCompleted` and
  /// trigger the celebration exactly once, right after the contribution
  /// that pushed it over the line.
  Future<AppSavingsGoal> contribute(int id, double amount) async {
    final repo = ref.read(goalRepositoryProvider);
    final updated = await repo.contribute(id, amount);
    ref.invalidateSelf();
    ref.read(piggyCoinFlipProvider.notifier).state++; // Hami flips a coin for progress
    await future;
    return updated;
  }

  Future<void> deleteGoal(int id) async {
    final repo = ref.read(goalRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<AppSavingsGoal>>(GoalsNotifier.new);
