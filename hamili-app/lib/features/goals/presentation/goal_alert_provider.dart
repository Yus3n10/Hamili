import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';

/// Goal ids whose "goal met" celebration the user has closed this session.
/// In-memory only and reset on session change (logout), so a completed goal's
/// celebration returns next cold start until dismissed again.
class DismissedGoalAlertsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(sessionIdProvider); // reset on login/logout
    return <int>{};
  }

  void dismiss(int goalId) {
    state = {...state, goalId};
  }
}

final dismissedGoalAlertsProvider =
    NotifierProvider<DismissedGoalAlertsNotifier, Set<int>>(DismissedGoalAlertsNotifier.new);
