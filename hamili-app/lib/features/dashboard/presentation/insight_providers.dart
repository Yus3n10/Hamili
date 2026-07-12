import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../data/insights_repository.dart';
import '../domain/ai_insight.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) => InsightsRepository());

class InsightsNotifier extends AsyncNotifier<List<AiInsight>> {
  @override
  Future<List<AiInsight>> build() async {
    ref.watch(sessionIdProvider); // reset on login/logout (account isolation)
    return ref.read(insightsRepositoryProvider).get();
  }

  /// Force a fresh batch (a Gemini call). Keeps the old list visible while
  /// the new one loads instead of flashing empty.
  Future<void> refresh() async {
    state = const AsyncLoading<List<AiInsight>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(insightsRepositoryProvider).refresh());
  }

  /// Optimistically remove the dismissed insight; on failure, refetch.
  Future<void> dismiss(int id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((i) => i.id != id).toList());
    try {
      await ref.read(insightsRepositoryProvider).dismiss(id);
    } catch (_) {
      ref.invalidateSelf();
    }
  }
}

final insightsProvider = AsyncNotifierProvider<InsightsNotifier, List<AiInsight>>(InsightsNotifier.new);
