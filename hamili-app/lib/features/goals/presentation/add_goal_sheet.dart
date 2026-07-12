import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/primary_button.dart';
import 'goal_providers.dart';

Future<void> showAddGoalSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _AddGoalSheet(),
  );
}

class _AddGoalSheet extends ConsumerStatefulWidget {
  const _AddGoalSheet();

  @override
  ConsumerState<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<_AddGoalSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _targetDate;
  bool _isSaving = false;
  String? _error;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text);
    if (_titleController.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a title and a valid target amount');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await ref.read(goalsProvider.notifier).addGoal(
            title: _titleController.text.trim(),
            targetAmount: amount,
            targetDate: _targetDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = "Couldn't create goal. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
            Text('New savings goal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'What are you saving for?'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₱ '),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Target date (optional)'),
                child: Text(_targetDate != null ? DateFormat.yMMMd().format(_targetDate!) : 'No target date'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(label: 'Create Goal', onPressed: _save, isLoading: _isSaving),
          ],
        ),
      ),
    );
  }
}
