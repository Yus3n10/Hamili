import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';


class DismissedGoalAlertsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(sessionIdProvider);
    return <int>{};
  }

  void dismiss(int goalId) {
    state = {...state, goalId};
  }
}

final dismissedGoalAlertsProvider =
    NotifierProvider<DismissedGoalAlertsNotifier, Set<int>>(DismissedGoalAlertsNotifier.new);
