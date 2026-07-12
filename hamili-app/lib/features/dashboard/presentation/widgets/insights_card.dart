import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../insight_providers.dart';

/// "Insights from Hami" — proactive, AI-generated nudges on the dashboard.
/// Renders nothing when there are no insights and nothing is loading, to
/// keep the dashboard uncluttered; loads independently so it never blocks
/// the balance/transactions from rendering.
class InsightsCard extends ConsumerWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final insights = insightsAsync.valueOrNull ?? [];
    final isLoading = insightsAsync.isLoading;

    if (insights.isEmpty && !isLoading) return const SizedBox.shrink();

    return Card(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 20, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Insights from Hami', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh insights',
                    onPressed: () => ref.read(insightsProvider.notifier).refresh(),
                  ),
              ],
            ),
            for (final insight in insights)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(insight.message)),
                    InkWell(
                      onTap: () => ref.read(insightsProvider.notifier).dismiss(insight.id),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
