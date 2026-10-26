/// What Hami is reacting to. Each maps to an animation in the exported
/// avatar definition; [priority] decides whether it may cut in on another.
enum HamiReaction {
  idle('idle', 0),
  budgetConcern('budget-concern', 1),
  celebrateIncome('celebrate-income', 2),
  celebrateSavings('celebrate-savings', 2),
  answerYes('answer-yes', 2),
  answerNo('answer-no', 2),
  warnSpending('warn-spending', 3),
  // Same animation as warnSpending, with steam: the budget is past its limit
  // or the balance is below zero.
  overBudget('warn-spending', 3);

  const HamiReaction(this.animation, this.priority);

  final String animation;
  final int priority;

  bool get intense => this == overBudget;

  /// The chat reply's typed `answer` field, never its wording.
  static HamiReaction? fromAnswer(String? answer) => switch (answer) {
        'affirmative' => answerYes,
        'negative' => answerNo,
        'warning' => budgetConcern,
        _ => null,
      };

  /// Hami's reaction to a chat reply, from its typed fields alone: the
  /// reply text is deliberately not an input. Effects count only when the
  /// server reports the action went through.
  static HamiReaction? forChatReply({String? answer, String? effect, required bool actionDone}) {
    final gesture = fromAnswer(answer);
    if (gesture != null || !actionDone) return gesture;
    return switch (effect) {
      'income' => celebrateIncome,
      'savings' => celebrateSavings,
      _ => null,
    };
  }

  /// A budget's server-computed `alert_level`.
  static HamiReaction? fromBudgetLevel(String level) => switch (level) {
        'approaching' => budgetConcern,
        'high' => warnSpending,
        'over' => overBudget,
        _ => null,
      };
}
