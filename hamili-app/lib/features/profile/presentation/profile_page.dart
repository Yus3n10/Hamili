import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import 'edit_profile_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to access your data."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(currentUserProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        data: (user) => user == null
            ? const Center(child: Text('Not logged in'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(title: const Text('Preferred name'), subtitle: Text(user.preferredName)),
                  ListTile(title: const Text('Email'), subtitle: Text(user.email)),
                  ListTile(title: const Text('Currency'), subtitle: Text(user.preferredCurrency)),
                  ListTile(
                    title: const Text('Financial goal'),
                    subtitle: Text(user.financialGoalText ?? 'Not set yet'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _confirmLogout(context, ref),
                    child: const Text('Log out'),
                  ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Something went wrong')),
      ),
    );
  }
}
