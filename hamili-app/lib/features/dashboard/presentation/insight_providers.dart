import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../data/insights_repository.dart';
import '../domain/ai_insight.dart';
import 'insights_enabled_provider.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) => InsightsRepository());

class InsightsNotifier extends AsyncNotifier<List<AiInsight>> {
  @override
  Future<List<AiInsight>> build() async {
    ref.watch(sessionIdProvider);
    if (!ref.watch(insightsEnabledProvider)) return [];
    return ref.read(insightsRepositoryProvider).get();
  }


  Future<void> refresh() async {
    if (!ref.read(insightsEnabledProvider)) return;
    state = const AsyncLoading<List<AiInsight>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(insightsRepositoryProvider).refresh());
  }


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
