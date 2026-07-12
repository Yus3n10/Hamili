import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/category.dart';
import '../../domain/analytics_models.dart';

/// Donut of spending-by-category plus a ranked legend. Colors come from a
/// fixed palette assigned by rank, so the biggest slice is always the same
/// hue regardless of category.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.breakdown, required this.categories});

  final List<CategoryBreakdown> breakdown;
  final List<AppCategory> categories;

  static const List<Color> _palette = AppColors.chartPalette;

  String _nameFor(int categoryId) {
    final matches = categories.where((c) => c.id == categoryId);
    return matches.isNotEmpty ? matches.first.name : 'Uncategorized';
  }

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('No spending this month yet.')),
      );
    }

    final total = breakdown.fold(0.0, (sum, b) => sum + b.total);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 56,
              sections: [
                for (var i = 0; i < breakdown.length; i++)
                  PieChartSectionData(
                    value: breakdown[i].total,
                    color: _palette[i % _palette.length],
                    title: '',
                    radius: 44,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < breakdown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: _palette[i % _palette.length], shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_nameFor(breakdown[i].categoryId))),
                Text(CurrencyFormatter.format(breakdown[i].total)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    total > 0 ? '${(breakdown[i].total / total * 100).round()}%' : '0%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
