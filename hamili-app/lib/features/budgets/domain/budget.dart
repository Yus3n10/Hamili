class AppBudget {
  final int id;
  final int categoryId;
  final int month;
  final int year;
  final double limitAmount;
  final double spentAmount;
  final double remainingAmount;
  final double percentageUsed;

  const AppBudget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.limitAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
  });

  factory AppBudget.fromJson(Map<String, dynamic> json) => AppBudget(
        id: json['id'] as int,
        categoryId: json['category_id'] as int,
        month: json['month'] as int,
        year: json['year'] as int,
        limitAmount: (json['limit_amount'] as num).toDouble(),
        spentAmount: (json['spent_amount'] as num).toDouble(),
        remainingAmount: (json['remaining_amount'] as num).toDouble(),
        percentageUsed: (json['percentage_used'] as num).toDouble(),
      );
}
