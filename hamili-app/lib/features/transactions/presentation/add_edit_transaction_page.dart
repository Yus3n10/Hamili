import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/offline_queue.dart';
import '../../../core/utils/thousands_separator_formatter.dart';
import '../../../shared/widgets/category_picker.dart';
import '../../../shared/widgets/primary_button.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';
import 'transaction_providers.dart';


class AddEditTransactionPage extends ConsumerStatefulWidget {
  const AddEditTransactionPage({super.key, this.transaction});

  final AppTransaction? transaction;

  @override
  ConsumerState<AddEditTransactionPage> createState() => _AddEditTransactionPageState();
}

class _AddEditTransactionPageState extends ConsumerState<AddEditTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _customCategoryController = TextEditingController();

  late String _type;
  AppCategory? _selectedCategory;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;
  bool _categoryPrefilled = false;

  bool get _isEditing => widget.transaction != null;


  bool get _isOthersCategory => _selectedCategory?.name.toLowerCase() == 'others';

  @override
  void initState() {
    super.initState();
    _type = widget.transaction?.type ?? 'expense';
    if (widget.transaction != null) {
      _amountController.text = NumberFormat('#,##0.00').format(widget.transaction!.amount);
      _date = widget.transaction!.transactionDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }


  void _prefillCategoryIfNeeded(List<AppCategory> categories) {
    if (_categoryPrefilled || widget.transaction == null || categories.isEmpty) return;
    _categoryPrefilled = true;

    final matches = categories.where((c) => c.id == widget.transaction!.categoryId);
    final category = matches.isNotEmpty ? matches.first : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedCategory = category;
        if (category?.name.toLowerCase() == 'others') {
          _customCategoryController.text = widget.transaction!.note ?? '';
        } else {
          _noteController.text = widget.transaction!.note ?? '';
        }
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showCategoryPicker(context, type: _type);
    if (picked != null) {
      setState(() {
        _selectedCategory = picked;


        if (picked.name.toLowerCase() != 'others') _customCategoryController.clear();
      });
    }
  }


  String _buildNoteForSubmission() {
    if (!_isOthersCategory) return _noteController.text.trim();

    final label = _customCategoryController.text.trim();
    final extra = _noteController.text.trim();
    return extra.isEmpty ? label : '$label - $extra';
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


    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final notifier = ref.read(transactionsProvider.notifier);
      final amount = ThousandsSeparatorInputFormatter.parseAmount(_amountController.text)!;
      final note = _buildNoteForSubmission();

      if (_isEditing) {
        await notifier.editTransaction(
          widget.transaction!.id,
          categoryId: _selectedCategory!.id,
          amount: amount,
          note: note,
          transactionDate: _date,
        );
      } else {
        await notifier.addTransaction(
          categoryId: _selectedCategory!.id,
          amount: amount,
          type: _type,
          transactionDate: _date,
          note: note,
        );
      }

      if (mounted) navigator.pop();
    } on OfflineQueuedException {

      if (mounted) navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Saved offline — it’ll sync when you’re back online.')),
      );
    } catch (_) {
      setState(() => _errorMessage = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    categoriesAsync.whenData(_prefillCategoryIfNeeded);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction')),
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
                      ? null
                      : (selection) => setState(() {
                            _type = selection.first;
                            _selectedCategory = null;
                            _customCategoryController.clear();
                          }),
                ),
                const SizedBox(height: 20),
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


                if (_isOthersCategory) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customCategoryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Specify category',
                      hintText: 'e.g. Haircut, Pet supplies, Gift',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "Please type what this 'Others' expense is for";
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat.yMMMd().format(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: _isEditing ? 'Save Changes' : 'Add Transaction', onPressed: _save, isLoading: _isSaving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
