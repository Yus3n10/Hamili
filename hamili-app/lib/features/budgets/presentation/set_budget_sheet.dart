import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/category_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../transactions/domain/category.dart';
import '../domain/budget.dart';
import 'budget_providers.dart';

enum _BudgetConflictChoice { replace, add }

Future<void> showSetBudgetSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _SetBudgetSheet(),
  );
}

class _SetBudgetSheet extends ConsumerStatefulWidget {
  const _SetBudgetSheet();

  @override
  ConsumerState<_SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<_SetBudgetSheet> {
  final _amountController = TextEditingController();
  AppCategory? _selectedCategory;
  bool _isSaving = false;
  String? _error;

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, type: 'expense');
    if (picked != null) setState(() => _selectedCategory = picked);
  }

  Future<void> _save() async {
    final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text);
    if (_selectedCategory == null || amount == null || amount <= 0) {
      setState(() => _error = 'Pick a category and enter a valid amount');
      return;
    }


    final budgets = ref.read(budgetsProvider).valueOrNull ?? const <AppBudget>[];
    AppBudget? existing;
    for (final b in budgets) {
      if (b.categoryId == _selectedCategory!.id) {
        existing = b;
        break;
      }
    }

    var finalAmount = amount;
    if (existing != null) {
      final choice = await _askReplaceOrAdd(existing.limitAmount, amount);
      if (choice == null) return;
      finalAmount = choice == _BudgetConflictChoice.add ? existing.limitAmount + amount : amount;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(budgetsProvider.notifier).setBudget(categoryId: _selectedCategory!.id, limitAmount: finalAmount);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = "Couldn't save budget. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_BudgetConflictChoice?> _askReplaceOrAdd(double existing, double added) {
    final total = existing + added;
    return showDialog<_BudgetConflictChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_selectedCategory!.name} already has a budget'),
        content: Text(
          'This category already has a ${CurrencyFormatter.format(existing)} budget this month.\n\n'
          'Replace it with ${CurrencyFormatter.format(added)}, or add them together?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _BudgetConflictChoice.replace),
            child: const Text('Replace'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _BudgetConflictChoice.add),
            child: Text('Add → ${CurrencyFormatter.format(total)}'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set a monthly budget', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickCategory,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Category'),
                child: Text(_selectedCategory?.name ?? 'Select a category'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(labelText: 'Monthly limit', prefixText: '₱ '),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: 'Save Budget', onPressed: _save, isLoading: _isSaving),
          ],
        ),
      ),
    );
  }
}
