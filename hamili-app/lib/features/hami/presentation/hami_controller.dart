import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';
import '../domain/budget_alert_tracker.dart';
import '../domain/hami_definition.dart';
import '../domain/hami_reaction.dart';

final hamiDefinitionProvider = FutureProvider<HamiDefinition>((ref) => HamiDefinition.load());

/// The one reaction every Hami on screen is playing. [seq] changes on every
/// new reaction, so widgets restart even when the same reaction repeats.
class HamiPlayback {
  final HamiReaction reaction;
  final int seq;
  final String? caption;

  const HamiPlayback(this.reaction, this.seq, {this.caption});

  bool get isIdle => reaction == HamiReaction.idle;
}

class HamiController extends Notifier<HamiPlayback> {
  Timer? _timer;

  static const _fallback = Duration(milliseconds: 2400);

  @override
  HamiPlayback build() {
    ref.watch(sessionIdProvider);
    ref.onDispose(() => _timer?.cancel());
    return const HamiPlayback(HamiReaction.idle, 0);
  }

  /// Starts [reaction] unless a stronger one is still playing. Returns
  /// whether it started. Hami goes back to idle when it finishes.
  bool play(HamiReaction reaction, {String? caption}) {
    if (reaction == HamiReaction.idle) {
      _toIdle();
      return true;
    }
    if (!state.isIdle && reaction.priority < state.reaction.priority) return false;
    _timer?.cancel();
    final seq = state.seq + 1;
    state = HamiPlayback(reaction, seq, caption: caption);
    _timer = Timer(_durationOf(reaction), () {
      if (state.seq == seq) _toIdle();
    });
    return true;
  }

  void _toIdle() {
    _timer?.cancel();
    _timer = null;
    if (!state.isIdle) state = HamiPlayback(HamiReaction.idle, state.seq + 1);
  }

  Duration _durationOf(HamiReaction reaction) {
    final anim = ref.read(hamiDefinitionProvider).valueOrNull?.animations[reaction.animation];
    if (anim == null || anim.loops) return _fallback;
    return Duration(milliseconds: anim.durationMs);
  }
}

final hamiControllerProvider = NotifierProvider<HamiController, HamiPlayback>(HamiController.new);

final budgetAlertTrackerProvider = Provider<BudgetAlertTracker>((ref) {
  ref.watch(sessionIdProvider);
  return BudgetAlertTracker();
});
