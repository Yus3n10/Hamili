import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/category_visuals.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/recurring_item.dart';
import 'add_edit_recurring_page.dart';
import 'recurring_providers.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  Future<void> _runDue(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final promoted = await ref.read(recurringProvider.notifier).runDue();
      messenger.showSnackBar(SnackBar(
        content: Text(promoted == 0 ? 'Nothing due right now.' : 'Added $promoted transaction(s).'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't run recurring items.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'run') _runDue(context, ref);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'run', child: Text('Run due now')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditRecurringPage()),
        ),
        child: const Icon(Icons.add),
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load recurring items."),
              const SizedBox(height: 12),
              TextButton(onPressed: () => ref.invalidate(recurringProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recurring items yet. Tap + to add a salary, rent, or subscription.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final income = items.where((i) => i.type == 'income').toList();
          final expenses = items.where((i) => i.type == 'expense').toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(recurringProvider.future),
            child: ListView(
              children: [
                if (income.isNotEmpty) _sectionHeader('Income'),
                ...income.map((i) => _tile(context, ref, i, categories)),
                if (expenses.isNotEmpty) _sectionHeader('Expenses'),
                ...expenses.map((i) => _tile(context, ref, i, categories)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _tile(BuildContext context, WidgetRef ref, RecurringItem item, List<AppCategory> categories) {
    final matches = categories.where((c) => c.id == item.categoryId);
    final icon = matches.isNotEmpty ? CategoryVisuals.iconFor(matches.first.icon) : Icons.autorenew;
    final freqLabel = '${item.frequency[0].toUpperCase()}${item.frequency.substring(1)}';
    final nextLabel = DateFormat.MMMd().format(item.nextDueDate);

    return Dismissible(
      key: ValueKey('recurring_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => ref.read(recurringProvider.notifier).deleteItem(item.id),
      child: ListTile(
        leading: Icon(icon),
        title: Text(item.name),
        subtitle: Text('$freqLabel · next: $nextLabel'),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddEditRecurringPage(item: item)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurrencyFormatter.format(item.amount)),
            const SizedBox(width: 8),
            Switch(
              value: item.active,
              onChanged: (value) => ref.read(recurringProvider.notifier).toggleActive(item.id, value),
            ),
          ],
        ),
      ),
    );
  }
}
