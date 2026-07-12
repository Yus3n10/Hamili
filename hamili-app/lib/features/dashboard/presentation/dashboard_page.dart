import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mascot/piggy_events.dart';
import '../../../core/network/offline_queue.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/piggy_mascot.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../analytics/presentation/analytics_page.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../transactions/presentation/add_edit_transaction_page.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import 'widgets/insights_card.dart';
import 'widgets/summary_card.dart';

/// Balance/income/expense figures are computed client-side from the
/// already-fetched transaction list for now — this avoids a second
/// network round-trip and keeps Milestone 2 simple. A dedicated
/// `/analytics/summary` endpoint (Milestone 5) will take over once the
/// dataset is large enough that summing client-side stops being free.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: userAsync.when(
          data: (user) => Text(user != null ? 'Hi, ${user.preferredName} 👋' : 'Dashboard'),
          loading: () => const Text('Dashboard'),
          error: (_, __) => const Text('Dashboard'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditTransactionPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          // Totals are now server-computed (Milestone 5) instead of summed
          // client-side; the recent list still comes from the transactions
          // fetch. Until the summary resolves, show zeros rather than block.
          final recent = transactions.take(5).toList();
          final summary = summaryAsync.valueOrNull;
          final income = summary?.income ?? 0;
          final expense = summary?.expense ?? 0;
          final balance = summary?.net ?? 0;

          return RefreshIndicator(
            onRefresh: () {
              ref.invalidate(dashboardSummaryProvider);
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
                        borderRadius: BorderRadius.circular(8),
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
                _BalanceHero(balance: balance),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: 'Income',
                        amount: income,
                        color: AppColors.income,
                        icon: Icons.arrow_downward,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: 'Expenses',
                        amount: expense,
                        color: AppColors.expense,
                        icon: Icons.arrow_upward,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const _DashboardMascot(),
                const SizedBox(height: 12),
                const InsightsCard(),
                const SizedBox(height: 12),
                Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium),
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
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AddEditTransactionPage(transaction: transaction)),
                          ),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load your data. Pull down to retry.")),
      ),
    );
  }
}

/// The dashboard piggy mascot — does a coin flip on load and whenever a
/// celebratory event fires (income added, goal progress).
class _DashboardMascot extends ConsumerStatefulWidget {
  const _DashboardMascot();

  @override
  ConsumerState<_DashboardMascot> createState() => _DashboardMascotState();
}

class _DashboardMascotState extends ConsumerState<_DashboardMascot> {
  final PiggyMascotController _piggy = PiggyMascotController();

  @override
  Widget build(BuildContext context) {
    ref.listen(piggyCoinFlipProvider, (_, __) => _piggy.coinFlip());
    return Center(
      child: PiggyMascot(size: 116, controller: _piggy, coinFlipOnInit: true),
    );
  }
}

/// Balance hero: gold gradient with two translucent orbs that slowly drift
/// for continuous ambient motion, a wallet chip, and a count-up figure.
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
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3A2B00), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('Current Balance',
                          style: TextStyle(color: Color(0xFF3A2B00), fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Count-up so the balance reads as "tallied". Dark text on gold passes WCAG.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: balance),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      CurrencyFormatter.format(value),
                      style: const TextStyle(color: Color(0xFF241A05), fontSize: 34, fontWeight: FontWeight.w800),
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
