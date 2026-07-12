import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/primary_button.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_providers.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _goalController;
  late String _currency;
  bool _saving = false;
  String? _error;

  static const _currencies = ['PHP', 'USD', 'EUR', 'GBP', 'JPY'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.preferredName);
    _goalController = TextEditingController(text: widget.user.financialGoalText ?? '');
    _currency = _currencies.contains(widget.user.preferredCurrency) ? widget.user.preferredCurrency : 'PHP';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).updateProfile(
            preferredName: _nameController.text.trim(),
            preferredCurrency: _currency,
            financialGoalText: _goalController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = "Couldn't save. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Preferred name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: 'Preferred currency'),
                  items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (v) => setState(() => _currency = v ?? 'PHP'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goalController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Financial goal'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save Changes', onPressed: _save, isLoading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
