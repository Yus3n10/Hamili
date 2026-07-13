import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_provider.dart';


class DismissedBudgetAlertsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(sessionIdProvider);
    return <int>{};
  }

  void dismiss(int budgetId) {
    state = {...state, budgetId};
  }
}

final dismissedBudgetAlertsProvider =
    NotifierProvider<DismissedBudgetAlertsNotifier, Set<int>>(DismissedBudgetAlertsNotifier.new);
