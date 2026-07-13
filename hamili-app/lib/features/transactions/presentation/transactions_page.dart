import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/skeleton.dart';
import 'add_edit_transaction_page.dart';
import 'transaction_providers.dart';
import 'widgets/transaction_tile.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(transactionFilterProvider.notifier).update((state) => state.copyWith(search: value));
  }

  Future<void> _openCategoryFilter() async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];

    final picked = await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All categories'),
              onTap: () => Navigator.of(context).pop('clear'),
            ),
            ...categories.map(
              (c) => ListTile(title: Text(c.name), onTap: () => Navigator.of(context).pop(c.id)),
            ),
          ],
        ),
      ),
    );

    if (picked == 'clear') {
      ref.read(transactionFilterProvider.notifier).update((state) => state.copyWith(clearCategory: true));
    } else if (picked is int) {
      ref.read(transactionFilterProvider.notifier).update((state) => state.copyWith(categoryId: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(tooltip: 'Filter by category', onPressed: _openCategoryFilter, icon: const Icon(Icons.filter_list)),
        ],
      ),
      floatingActionButton: FloatingActionButton(


        onPressed: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const AddEditTransactionPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No transactions yet. Tap + to add your first one.', textAlign: TextAlign.center),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(transactionsProvider.future),
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final matches = categories.where((c) => c.id == transaction.categoryId);
                      final category = matches.isNotEmpty ? matches.first : null;
                      return TransactionTile(
                        transaction: transaction,
                        category: category,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AddEditTransactionPage(transaction: transaction)),
                        ),
                        onDelete: () => ref.read(transactionsProvider.notifier).deleteTransaction(transaction.id),
                      )
                          .animate(delay: (40 * (index % 12)).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
                );
              },
              loading: () => const SkeletonList(),
              error: (_, __) => const Center(child: Text("Couldn't load transactions.")),
            ),
          ),
        ],
      ),
    );
  }
}
