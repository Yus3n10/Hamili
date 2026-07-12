import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';

/// Budget ids whose over-limit alert the user has closed this session. In-memory
/// only and reset when the session changes (logout), so a dismissed alert returns
/// on the next cold start / login if the budget is still over limit.
class DismissedBudgetAlertsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(sessionIdProvider); // reset on login/logout
    return <int>{};
  }

  void dismiss(int budgetId) {
    state = {...state, budgetId};
  }
}

final dismissedBudgetAlertsProvider =
    NotifierProvider<DismissedBudgetAlertsNotifier, Set<int>>(DismissedBudgetAlertsNotifier.new);
