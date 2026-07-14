import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/category_visuals.dart';
import '../../transactions/domain/category.dart';
import '../domain/budget.dart';
import 'budget_providers.dart';


class BudgetDetailPage extends ConsumerWidget {
  const BudgetDetailPage({super.key, required this.budget, required this.category});

  final AppBudget budget;
  final AppCategory? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(budgetTransactionsProvider(budget.categoryId));
    final categoryName = category?.name ?? 'Uncategorized';
    final monthLabel = DateFormat.yMMMM().format(DateTime(budget.year, budget.month));

    final isOver = budget.percentageUsed >= 100;
    final isNear = budget.percentageUsed >= 80 && !isOver;
    final progressColor = isOver
        ? AppColors.expense
        : isNear
            ? AppColors.warning
            : context.accent;

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CategoryVisuals.iconFor(category?.icon), size: 20),
                      const SizedBox(width: 8),
                      Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        isOver
                            ? 'Over by ${CurrencyFormatter.format(budget.spentAmount - budget.limitAmount)}'
                            : '${CurrencyFormatter.format(budget.remainingAmount)} left',
                        style: TextStyle(color: progressColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Couldn't load transactions."),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(budgetTransactionsProvider(budget.categoryId)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (all) {


                final txns = all
                    .where((t) =>
                        t.type == 'expense' &&
                        t.transactionDate.month == budget.month &&
                        t.transactionDate.year == budget.year)
                    .toList()
                  ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

                if (txns.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No spending in this category yet this month.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(budgetTransactionsProvider(budget.categoryId).future),
                  child: ListView.separated(
                    itemCount: txns.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = txns[index];
                      final hasNote = t.note?.isNotEmpty ?? false;
                      final title = hasNote ? t.note! : categoryName;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.expense.withValues(alpha: 0.15),
                          child: Icon(CategoryVisuals.iconFor(category?.icon), color: AppColors.expense, size: 20),
                        ),
                        title: Text(title),
                        subtitle: Text(DateFormat.yMMMd().format(t.transactionDate)),
                        trailing: Text(
                          '-${CurrencyFormatter.format(t.amount)}',
                          style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
