class AnalyticsSummary {
  final double income;
  final double expense;
  final double net;

  const AnalyticsSummary({required this.income, required this.expense, required this.net});

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => AnalyticsSummary(
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
        net: (json['net'] as num).toDouble(),
      );
}

class CategoryBreakdown {
  final int categoryId;
  final double total;

  const CategoryBreakdown({required this.categoryId, required this.total});

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) => CategoryBreakdown(
        categoryId: json['category_id'] as int,
        total: (json['total'] as num).toDouble(),
      );
}

class TrendPoint {
  final int year;
  final int month;
  final double income;
  final double expense;

  const TrendPoint({required this.year, required this.month, required this.income, required this.expense});

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        year: json['year'] as int,
        month: json['month'] as int,
        income: (json['income'] as num).toDouble(),
        expense: (json['expense'] as num).toDouble(),
      );
}
