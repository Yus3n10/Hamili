import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Budgets', Icons.pie_chart_outline, '/budgets'),
      ('Savings Goals', Icons.savings_outlined, '/goals'),
      ('Recurring', Icons.autorenew, '/recurring'),
      ('Profile', Icons.person_outline, '/profile'),
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
