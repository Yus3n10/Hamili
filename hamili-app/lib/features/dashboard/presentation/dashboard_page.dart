import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/offline_queue.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/hamili_logo.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../budgets/presentation/budgets_page.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../goals/presentation/goals_page.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/add_edit_transaction_page.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/transactions_page.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import 'widgets/insights_card.dart';
import 'widgets/spending_chart.dart';
import 'widgets/summary_card.dart';


class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  AppSavingsGoal? _activeGoal(List<AppSavingsGoal> goals) {
    final open = goals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    if (open.isNotEmpty) return open.first;
    return goals.isNotEmpty ? goals.first : null;
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <AppCategory>[];
    final summary = ref.watch(dashboardSummaryProvider).valueOrNull;
    final monthly = ref.watch(monthlySummaryProvider).valueOrNull;
    final goals = ref.watch(goalsProvider).valueOrNull ?? const <AppSavingsGoal>[];
    final budgets = ref.watch(budgetsProvider).valueOrNull ?? const <AppBudget>[];
    final activeGoal = _activeGoal(goals);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        leading: const Padding(padding: EdgeInsets.only(left: 16), child: HamiliLogo(size: 30)),
        title: userAsync.when(
          data: (user) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_timeGreeting(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              Text(user != null ? 'Hi, ${user.preferredName}' : 'Dashboard',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          loading: () => const Text('Dashboard'),
          error: (_, __) => const Text('Dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(


        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const AddEditTransactionPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final recent = transactions.take(5).toList();
          final balance = summary?.net ?? 0;
          final mIncome = monthly?.income ?? 0;
          final mSpend = monthly?.expense ?? 0;

          return RefreshIndicator(
            onRefresh: () {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(monthlySummaryProvider);
              ref.invalidate(goalsProvider);
              ref.invalidate(budgetsProvider);
              return ref.refresh(transactionsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: OfflineQueue.instance.pendingCount,
                  builder: (context, count, _) {
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text('$count change${count == 1 ? '' : 's'} waiting to sync')),
                        ],
                      ),
                    );
                  },
                ),
                if (activeGoal != null)
                  _ActiveGoalCard(goal: activeGoal, onAddFunds: () => _push(context, const GoalsPage()))
                else
                  _NoGoalCard(onCreate: () => _push(context, const GoalsPage())),
                const SizedBox(height: 12),
                _BalanceHero(balance: balance),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: 'Income',
                        amount: mIncome,
                        color: AppColors.income,
                        icon: Icons.arrow_downward,
                        onTap: () => _push(context, const TransactionsPage()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: 'Spending',
                        amount: mSpend,
                        color: AppColors.expense,
                        icon: Icons.arrow_upward,
                        onTap: () => _push(context, const TransactionsPage()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SpendingChart(transactions: transactions),
                const SizedBox(height: 12),
                const InsightsCard(),
                const SizedBox(height: 12),
                _SectionHeader(title: 'Budgets', action: 'Manage', onAction: () => _push(context, const BudgetsPage())),
                const SizedBox(height: 8),
                _BudgetsMini(budgets: budgets, categories: categories),
                const SizedBox(height: 16),
                _SectionHeader(
                    title: 'Recent activity', action: 'See all', onAction: () => _push(context, const TransactionsPage())),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nothing here yet — add your first transaction.')),
                  )
                else
                  Card(
                    child: Column(
                      children: recent.map((transaction) {
                        final matches = categories.where((c) => c.id == transaction.categoryId);
                        final category = matches.isNotEmpty ? matches.first : null;
                        return TransactionTile(
                          transaction: transaction,
                          category: category,
                          onTap: () => _push(context, AddEditTransactionPage(transaction: transaction)),
                          onDelete: () => ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id),
                        );
                      }).toList(),
                    ),
                  ),
              ]
                  .animate(interval: 65.ms)
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
            ),
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonCard(height: 120),
            SizedBox(height: 12),
            SkeletonCard(height: 88),
            SizedBox(height: 12),
            Row(children: [
              Expanded(child: SkeletonCard(height: 78)),
              SizedBox(width: 12),
              Expanded(child: SkeletonCard(height: 78)),
            ]),
            SizedBox(height: 16),
            SkeletonList(count: 4),
          ],
        ),
        error: (_, __) => const Center(child: Text("Couldn't load your data. Pull down to retry.")),
      ),
    );
  }
}


class _ActiveGoalCard extends StatelessWidget {
  const _ActiveGoalCard({required this.goal, required this.onAddFunds});

  final AppSavingsGoal goal;
  final VoidCallback onAddFunds;

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progressPercentage / 100).clamp(0.0, 1.0);
    final subtitle = '${CurrencyFormatter.format(goal.currentAmount)} of ${CurrencyFormatter.format(goal.targetAmount)}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text('ACTIVE GOAL',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${goal.progressPercentage.round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          Text(goal.title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onAddFunds,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text('Add funds'),
            ),
          ),
        ],
      ),
    );
  }
}


class _NoGoalCard extends StatelessWidget {
  const _NoGoalCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('What are you saving for? Set a goal and Hami will help you get there.'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onCreate, child: const Text('Add goal')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, required this.onAction});

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }
}


class _BudgetsMini extends StatelessWidget {
  const _BudgetsMini({required this.budgets, required this.categories});

  final List<AppBudget> budgets;
  final List<AppCategory> categories;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('No budgets set for this month yet.'),
        ),
      );
    }
    final shown = budgets.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final b in shown) _budgetRow(context, b),
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(BuildContext context, AppBudget b) {
    final matches = categories.where((c) => c.id == b.categoryId);
    final name = matches.isNotEmpty ? matches.first.name : 'Uncategorized';
    final pct = (b.percentageUsed / 100).clamp(0.0, 1.0);
    final over = b.spentAmount > b.limitAmount;
    final color = over ? AppColors.expense : (b.percentageUsed >= 80 ? AppColors.warning : AppColors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${CurrencyFormatter.format(b.spentAmount)} of ${CurrencyFormatter.format(b.limitAmount)}',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}


class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});

  final double balance;

  Widget _orb(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: opacity), shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -28,
              right: -10,
              child: _orb(96, 0.16)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: -8, end: 10, duration: 3200.ms, curve: Curves.easeInOut)
                  .scaleXY(begin: 1, end: 1.15, duration: 4000.ms, curve: Curves.easeInOut),
            ),
            Positioned(
              bottom: -34,
              left: -12,
              child: _orb(84, 0.12)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 8, end: -8, duration: 3800.ms, curve: Curves.easeInOut)
                  .moveX(begin: -4, end: 12, duration: 4600.ms, curve: Curves.easeInOut),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('Total balance',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: balance),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      CurrencyFormatter.format(value),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
