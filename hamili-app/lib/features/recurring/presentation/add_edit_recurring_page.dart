import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/category_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/recurring_item.dart';
import 'recurring_providers.dart';

/// One form for both add (item == null) and edit (item != null).
class AddEditRecurringPage extends ConsumerStatefulWidget {
  const AddEditRecurringPage({super.key, this.item});

  final RecurringItem? item;

  @override
  ConsumerState<AddEditRecurringPage> createState() => _AddEditRecurringPageState();
}

class _AddEditRecurringPageState extends ConsumerState<AddEditRecurringPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late String _type;
  String _frequency = 'monthly';
  AppCategory? _selectedCategory;
  DateTime _nextDue = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;
  bool _categoryPrefilled = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _type = widget.item?.type ?? 'expense';
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _amountController.text = NumberFormat('#,##0.00').format(widget.item!.amount);
      _frequency = widget.item!.frequency;
      _nextDue = widget.item!.nextDueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Editing only carries categoryId; resolve the full AppCategory once
  /// categoriesProvider loads so the field shows the real name instead of
  /// "Select a category" (the bug #12 class — edit never pre-selecting).
  void _prefillCategoryIfNeeded(List<AppCategory> categories) {
    if (_categoryPrefilled || widget.item == null || categories.isEmpty) return;
    _categoryPrefilled = true;
    final matches = categories.where((c) => c.id == widget.item!.categoryId);
    final category = matches.isNotEmpty ? matches.first : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedCategory = category);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDue,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100), // recurring dates are usually in the future
    );
    if (picked != null) setState(() => _nextDue = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, type: _type);
    if (picked != null) setState(() => _selectedCategory = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Please choose a category');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final notifier = ref.read(recurringProvider.notifier);
      final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text)!;
      if (_isEditing) {
        await notifier.editItem(
          widget.item!.id,
          name: _nameController.text.trim(),
          amount: amount,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          nextDueDate: _nextDue,
        );
      } else {
        await notifier.addItem(
          type: _type,
          name: _nameController.text.trim(),
          amount: amount,
          categoryId: _selectedCategory!.id,
          frequency: _frequency,
          nextDueDate: _nextDue,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _errorMessage = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesProvider).whenData(_prefillCategoryIfNeeded);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Recurring' : 'Add Recurring')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isEditing
                      ? null // type is fixed once created (matches backend update schema)
                      : (selection) => setState(() {
                            _type = selection.first;
                            _selectedCategory = null;
                          }),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Salary, Rent, Netflix',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Give this a name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
                  validator: (value) {
                    final parsed = ThousandsSeparatorInputFormatter.parseAmount(value ?? '');
                    if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickCategory,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Category'),
                    child: Text(_selectedCategory?.name ?? 'Select a category'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Next due date'),
                    child: Text(DateFormat.yMMMd().format(_nextDue)),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isEditing ? 'Save Changes' : 'Add Recurring',
                  onPressed: _save,
                  isLoading: _isSaving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
