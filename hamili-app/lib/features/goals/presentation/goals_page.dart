import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/goal.dart';
import 'add_goal_sheet.dart';
import 'goal_providers.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  Future<void> _contribute(BuildContext context, WidgetRef ref, AppSavingsGoal goal) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to "${goal.title}"'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [ThousandsSeparatorInputFormatter()],
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              ThousandsSeparatorInputFormatter.parseAmount(controller.text),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || !context.mounted) return;

    final updated = await ref.read(goalsProvider.notifier).contribute(goal.id, amount);
    if (updated.isCompleted && context.mounted) {
      _showCelebration(context, updated);
    }
  }

  void _showCelebration(BuildContext context, AppSavingsGoal goal) {
    showDialog(
      context: context,
      builder: (context) => _CelebrationDialog(goal: goal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddGoalSheet(context),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No savings goals yet. Tap + to set one.', textAlign: TextAlign.center),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(goalsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progressColor = goal.isCompleted ? AppColors.income : AppColors.primary;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (goal.isCompleted) const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Text('🏆'),
                            ),
                            Expanded(
                              child: Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref.read(goalsProvider.notifier).deleteGoal(goal.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (goal.progressPercentage / 100).clamp(0, 1),
                            minHeight: 10,
                            backgroundColor: progressColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(progressColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${CurrencyFormatter.format(goal.currentAmount)} of ${CurrencyFormatter.format(goal.targetAmount)} '
                          '(${goal.progressPercentage.toStringAsFixed(0)}%)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!goal.isCompleted && goal.estimatedCompletionDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Estimated: ${DateFormat.yMMMd().format(goal.estimatedCompletionDate!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (!goal.isCompleted) ...[
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Add contribution',
                            onPressed: () => _contribute(context, ref, goal),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load savings goals.")),
      ),
    );
  }
}

/// Goal-completion celebration: the reached-goal message with a confetti
/// burst raining from the top. The controller lives with the dialog so it
/// is disposed cleanly when dismissed.
class _CelebrationDialog extends StatefulWidget {
  const _CelebrationDialog({required this.goal});

  final AppSavingsGoal goal;

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog> {
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.06,
              numberOfParticles: 22,
              minBlastForce: 8,
              maxBlastForce: 26,
              gravity: 0.3,
              colors: const [
                AppColors.primary,
                AppColors.income,
                AppColors.secondary,
                Color(0xFFEC4899),
                Color(0xFF9B6DFF),
              ],
            ),
          ),
          AlertDialog(
            title: const Text('🎉 Goal reached!'),
            content: Text(
              'You hit your "${widget.goal.title}" goal of ${CurrencyFormatter.format(widget.goal.targetAmount)}. Hami is proud of you!',
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Nice!')),
            ],
          ),
        ],
      ),
    );
  }
}
