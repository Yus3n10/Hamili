import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Deletes are permanent on the server, so every delete asks first.
Future<bool> confirmDelete(BuildContext context, {required String title, required String message}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.expenseText),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
