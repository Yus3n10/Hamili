import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/category_visuals.dart';
import '../../transactions/presentation/transaction_providers.dart';
import 'budget_providers.dart';
import 'set_budget_sheet.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final period = ref.watch(budgetPeriodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showSetBudgetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No budgets set for this month yet. Tap + to create one.', textAlign: TextAlign.center),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(budgetsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final budget = budgets[index];
                final matches = categories.where((c) => c.id == budget.categoryId);
                final category = matches.isNotEmpty ? matches.first : null;

                final isOverBudget = budget.percentageUsed >= 100;
                final isNearLimit = budget.percentageUsed >= 80 && !isOverBudget;
                final progressColor = isOverBudget
                    ? AppColors.expense
                    : isNearLimit
                        ? AppColors.warning
                        : AppColors.primary;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(CategoryVisuals.iconFor(category?.icon), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category?.name ?? 'Uncategorized',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => ref.read(budgetsProvider.notifier).deleteBudget(budget.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (budget.percentageUsed / 100).clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: progressColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(progressColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${CurrencyFormatter.format(budget.spentAmount)} of ${CurrencyFormatter.format(budget.limitAmount)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              isOverBudget
                                  ? 'Over by ${CurrencyFormatter.format(budget.spentAmount - budget.limitAmount)}'
                                  : '${CurrencyFormatter.format(budget.remainingAmount)} left',
                              style: TextStyle(
                                color: progressColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load budgets.")),
      ),
    );
  }
}
