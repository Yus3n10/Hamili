import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/skeleton.dart';
import '../admin_providers.dart';
import 'admin_error.dart';

const _viewNames = {
  '/admin/overview': 'Overview',
  '/admin/testers': 'Testers',
  '/admin/access-log': 'Access log',
};

class AdminAccessLogTab extends ConsumerWidget {
  const AdminAccessLogTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(adminAccessLogProvider);
    return log.when(
      loading: () => ListView(children: List.generate(6, (_) => const SkeletonTile())),
      error: (_, __) => AdminError(onRetry: () => ref.invalidate(adminAccessLogProvider)),
      data: (entries) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminAccessLogProvider.future),
        child: ListView.separated(
          itemCount: entries.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Every time the admin console loads data, it is recorded here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final entry = entries[index - 1];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.visibility_outlined, size: 20),
              title: Text('Viewed ${_viewNames[entry.path] ?? entry.path}'),
              trailing: Text(DateFormat('MMM d, h:mm a').format(entry.createdAt.toLocal())),
            );
          },
        ),
      ),
    );
  }
}
