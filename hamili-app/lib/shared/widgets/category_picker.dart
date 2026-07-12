import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/domain/category.dart';
import '../../features/transactions/presentation/transaction_providers.dart';
import 'category_visuals.dart';

/// Bottom-sheet category picker. Watches `categoriesProvider` directly
/// (rather than taking a pre-fetched list) so it always shows a loading
/// spinner if the fetch is still in flight, and an error state with a
/// retry if it failed — instead of silently rendering an empty list.
Future<AppCategory?> showCategoryPicker(
  BuildContext context, {
  required String type,
}) {
  return showModalBottomSheet<AppCategory>(
    context: context,
    builder: (context) => _CategoryPickerSheet(type: type),
  );
}

class _CategoryPickerSheet extends ConsumerWidget {
  const _CategoryPickerSheet({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: categoriesAsync.when(
        data: (categories) {
          final filtered = categories.where((c) => c.type == type).toList();
          if (filtered.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No categories available.', textAlign: TextAlign.center),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Choose a category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              ...filtered.map(
                (category) => ListTile(
                  leading: Icon(CategoryVisuals.iconFor(category.icon)),
                  title: Text(category.name),
                  onTap: () => Navigator.of(context).pop(category),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load categories.", textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(categoriesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
