import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../transactions/presentation/add_edit_transaction_page.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
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
          final income = transactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
          final expense = transactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);
          final balance = income - expense;
          final recent = transactions.take(5).toList();

          return RefreshIndicator(
            onRefresh: () => ref.refresh(transactionsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Balance', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(balance),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SummaryCard(
                        label: 'Income',
                        amount: income,
                        color: AppColors.income,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SummaryCard(
                        label: 'Expenses',
                        amount: expense,
                        color: AppColors.expense,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text("Couldn't load your data. Pull down to retry.")),
      ),
    );
  }
}
