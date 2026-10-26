import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider).value?.isAdmin ?? false;
    final items = [
      ('Budgets', Icons.pie_chart_outline, '/budgets'),
      ('Savings Goals', Icons.savings_outlined, '/goals'),
      ('Recurring', Icons.autorenew, '/recurring'),
      ('Profile', Icons.person_outline, '/profile'),
      if (isAdmin) ('Admin', Icons.admin_panel_settings_outlined, '/admin'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final (label, icon, route) = items[index];
          return ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(route),
          );
        },
      ),
    );
  }
}
