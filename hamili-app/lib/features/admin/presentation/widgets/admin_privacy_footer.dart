import 'package:flutter/material.dart';

// Shown on every admin tab so the limits of the console are never out of view.
class AdminPrivacyFooter extends StatelessWidget {
  const AdminPrivacyFooter({super.key});

  static const text =
      'Admins see names, emails and usage counts only. Amounts, notes and Hami chats are never shown.';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted))),
        ],
      ),
    );
  }
}
