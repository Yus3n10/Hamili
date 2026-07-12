class AppUser {
  final int id;
  final String email;
  final String preferredName;
  final String preferredCurrency;
  final double? monthlySalary;
  final double? allowance;
  final String? financialGoalText;

  const AppUser({
    required this.id,
    required this.email,
    required this.preferredName,
    required this.preferredCurrency,
    this.monthlySalary,
    this.allowance,
    this.financialGoalText,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      preferredName: json['preferred_name'] as String,
      preferredCurrency: json['preferred_currency'] as String,
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble(),
      allowance: (json['allowance'] as num?)?.toDouble(),
      financialGoalText: json['financial_goal_text'] as String?,
    );
  }
}
