import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/skeleton.dart';
import '../../domain/admin_models.dart';
import '../admin_providers.dart';
import 'admin_error.dart';

final _compact = NumberFormat.compact();

class AdminTestersTab extends ConsumerStatefulWidget {
  const AdminTestersTab({super.key});

  @override
  ConsumerState<AdminTestersTab> createState() => _AdminTestersTabState();
}

class _AdminTestersTabState extends ConsumerState<AdminTestersTab> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) ref.read(adminSearchProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final testers = ref.watch(adminTestersProvider);
    final sort = ref.watch(adminSortProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search testers',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Sort testers',
                initialValue: sort,
                onSelected: (value) => ref.read(adminSortProvider.notifier).state = value,
                itemBuilder: (_) => [
                  for (final entry in adminSorts.entries) PopupMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                child: Chip(avatar: const Icon(Icons.sort, size: 18), label: Text(adminSorts[sort]!)),
              ),
            ],
          ),
        ),
        Expanded(
          child: testers.when(
            loading: () => ListView(children: List.generate(6, (_) => const SkeletonTile())),
            error: (_, __) => AdminError(onRetry: () => ref.invalidate(adminTestersProvider)),
            data: (page) {
              if (page.items.isEmpty) {
                return Center(
                  child: Text(
                    ref.read(adminSearchProvider).isEmpty ? 'No testers yet.' : 'No testers match that search.',
                  ),
                );
              }
              final now = DateTime.now();
              return RefreshIndicator(
                onRefresh: () => ref.refresh(adminTestersProvider.future),
                child: ListView.separated(
                  itemCount: page.items.length + (page.total > page.items.length ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == page.items.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Showing ${page.items.length} of ${page.total}. Search to narrow it down.'),
                      );
                    }
                    final tester = page.items[index];
                    return _TesterRow(tester: tester, now: now);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TesterRow extends StatelessWidget {
  const _TesterRow({required this.tester, required this.now});

  final AdminTester tester;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: () => _showTesterSheet(context, tester, now),
      title: Text(tester.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tester.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            '${tester.lastActiveLabel(now)} · Joined ${DateFormat.MMMd().format(tester.joinedAt.toLocal())}',
            style: text.bodySmall,
          ),
          Text(tester.usageSummary, style: text.bodySmall),
        ],
      ),
      isThreeLine: true,
    );
  }
}

void _showTesterSheet(BuildContext context, AdminTester t, DateTime now) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      Widget fact(String label, String value) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(label, style: text.bodyMedium)),
                Text(value, style: text.titleSmall),
              ],
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.name, style: text.titleLarge),
              Text(t.email, style: text.bodyMedium),
              const SizedBox(height: 16),
              fact('Joined', DateFormat.yMMMd().format(t.joinedAt.toLocal())),
              fact('Last active', t.lastActiveLabel(now).replaceFirst('Active ', '')),
              fact('Days active, last 30', '${t.daysActive30d}'),
              const Divider(height: 24),
              fact('Transactions', '${t.transactionsCount}'),
              fact('Budgets', '${t.budgetsCount}'),
              fact('Savings goals', '${t.goalsCount}'),
              const Divider(height: 24),
              fact('Hami messages', '${t.hamiMessagesTotal}'),
              fact('Tokens from chat', _compact.format(t.hamiTokensChat)),
              fact('Tokens from insights', _compact.format(t.hamiTokensInsight)),
              fact('Tokens, last 7 days', _compact.format(t.hamiTokens7d)),
            ],
          ),
        ),
      );
    },
  );
}
