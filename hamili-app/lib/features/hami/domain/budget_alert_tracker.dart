import '../../budgets/domain/budget.dart';
import 'hami_reaction.dart';

class BudgetAlert {
  final HamiReaction reaction;
  final AppBudget budget;
  const BudgetAlert(this.reaction, this.budget);
}

int _rank(String level) => switch (level) {
      'approaching' => 1,
      'high' => 2,
      'over' => 3,
      _ => 0,
    };

/// Turns refreshed budget lists into at most one Hami warning per real
/// threshold crossing. It reads the server's `alert_level`, never its own
/// arithmetic, and stays quiet unless the user just spent money in this app,
/// so a first load, a cached-then-fresh refresh or a remount never scolds.
class BudgetAlertTracker {
  BudgetAlertTracker({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, int> _seen = {};
  final Map<int, int> _announced = {};
  DateTime? _expectingUntil;
  DateTime? _balanceExpectingUntil;
  double? _lastNet;

  static const _window = Duration(seconds: 20);

  /// Call after a spending event succeeds; the next budget refresh may warn.
  void expectSpending() {
    _expectingUntil = _clock().add(_window);
    _balanceExpectingUntil = _expectingUntil;
  }

  /// Whether this balance is the moment spending pushed it below zero.
  bool updateBalance(double net) {
    final before = _lastNet;
    _lastNet = net;
    final until = _balanceExpectingUntil;
    if (before == null || until == null || !_clock().isBefore(until)) return false;
    if (before >= 0 && net < 0) {
      _balanceExpectingUntil = null;
      return true;
    }
    return false;
  }

  BudgetAlert? update(List<AppBudget> budgets) {
    final now = _clock();
    final expecting = _expectingUntil != null && now.isBefore(_expectingUntil!);
    BudgetAlert? strongest;
    var changed = false;
    for (final b in budgets) {
      // Offline placeholders have negative ids and no server spend yet.
      if (b.id < 0 || b.month != now.month || b.year != now.year) continue;
      final rank = _rank(b.alertLevel);
      final before = _seen[b.id];
      _seen[b.id] = rank;
      if (before == null) continue;
      if (rank < before) {
        _announced[b.id] = rank;
        continue;
      }
      if (rank > before) changed = true;
      if (!expecting || rank <= before || rank <= (_announced[b.id] ?? 0)) continue;
      final reaction = HamiReaction.fromBudgetLevel(b.alertLevel);
      if (reaction == null) continue;
      _announced[b.id] = rank;
      if (strongest == null || reaction.priority > strongest.reaction.priority) {
        strongest = BudgetAlert(reaction, b);
      }
    }
    if (changed) _expectingUntil = null;
    return strongest;
  }
}
