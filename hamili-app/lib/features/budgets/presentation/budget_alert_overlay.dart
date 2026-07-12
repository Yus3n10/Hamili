import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'budget_alert_provider.dart';
import 'budget_providers.dart';

/// Floating, closable alerts shown near the bottom of every authenticated screen
/// whenever a budget is over its limit. Reddish and translucent so it never fully
/// obstructs the content behind it. Mounted inside MainShell, so it follows the
/// user across tabs but never appears on login/onboarding.
class BudgetAlertOverlay extends ConsumerWidget {
  const BudgetAlertOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final dismissed = ref.watch(dismissedBudgetAlertsProvider);

    final over = budgets
        .where((b) => b.spentAmount > b.limitAmount && !dismissed.contains(b.id))
        .toList();
    if (over.isEmpty) return const SizedBox.shrink();

    String nameFor(int categoryId) {
      final match = categories.where((c) => c.id == categoryId);
      return match.isNotEmpty ? match.first.name : 'A budget';
    }

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final b in over)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _AlertToast(
                  key: ValueKey(b.id),
                  message:
                      '${nameFor(b.categoryId)} is ${CurrencyFormatter.format(b.spentAmount - b.limitAmount)} over budget',
                  onClose: () => ref.read(dismissedBudgetAlertsProvider.notifier).dismiss(b.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertToast extends StatelessWidget {
  const _AlertToast({super.key, required this.message, required this.onClose});

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
            color: AppColors.expense.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
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
