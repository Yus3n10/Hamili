class AppSavingsGoal {
  final int id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final double remainingAmount;
  final double progressPercentage;
  final DateTime? targetDate;
  final DateTime? estimatedCompletionDate;
  final String status; // "in_progress" | "completed"

  const AppSavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.progressPercentage,
    required this.status,
    this.targetDate,
    this.estimatedCompletionDate,
  });

  bool get isCompleted => status == 'completed';

  factory AppSavingsGoal.fromJson(Map<String, dynamic> json) => AppSavingsGoal(
        id: json['id'] as int,
        title: json['title'] as String,
        targetAmount: (json['target_amount'] as num).toDouble(),
        currentAmount: (json['current_amount'] as num).toDouble(),
        remainingAmount: (json['remaining_amount'] as num).toDouble(),
        progressPercentage: (json['progress_percentage'] as num).toDouble(),
        targetDate: json['target_date'] != null ? DateTime.parse(json['target_date'] as String) : null,
        estimatedCompletionDate: json['estimated_completion_date'] != null
            ? DateTime.parse(json['estimated_completion_date'] as String)
            : null,
        status: json['status'] as String,
      );
}
