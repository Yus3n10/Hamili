import 'package:flutter/material.dart';

// Testers can read here exactly what the Hamili admin console shows about
// them. Keep this in step with the admin API's field list.
class PrivacyNoticeTile extends StatelessWidget {
  const PrivacyNoticeTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: const Text('Privacy'),
      subtitle: const Text('What the Hamili admin can see'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What the admin can see', style: text.titleLarge),
                  const SizedBox(height: 12),
                  Text(
                    'Hamili is in testing, and its admin can see your name and email, when you joined '
                    'and were last active, and how much you use the app and Hami (counts only).',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Never your money, notes, or chats: amounts, balances, budgets, goals and your '
                    'conversations with Hami are not shown to anyone.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your password is stored scrambled, so no one can read it, including the admin.',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
