import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import 'goal_alert_provider.dart';
import 'goal_providers.dart';

/// Green, semi-transparent celebration toasts shown near the bottom of every
/// authenticated screen when a savings goal is met. Mirrors the red budget
/// over-limit overlay; closable by × or swipe, session-dismissed.
class GoalAlertOverlay extends ConsumerWidget {
  const GoalAlertOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider).valueOrNull ?? const [];
    final dismissed = ref.watch(dismissedGoalAlertsProvider);

    final met = goals.where((g) => g.isCompleted && !dismissed.contains(g.id)).toList();
    if (met.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in met)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _GoalToast(
                  key: ValueKey(g.id),
                  message: "You hit '${g.title}'! 🎉",
                  onClose: () => ref.read(dismissedGoalAlertsProvider.notifier).dismiss(g.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalToast extends StatelessWidget {
  const _GoalToast({super.key, required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onClose(),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            // Green + semi-transparent so it celebrates without blocking the view.
            color: AppColors.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                tooltip: 'Dismiss',
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.3, end: 0, duration: 250.ms);
  }
}
