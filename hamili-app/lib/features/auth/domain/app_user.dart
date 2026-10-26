class AppUser {
  final int id;
  final String email;
  final String preferredName;
  final String preferredCurrency;
  final double? monthlySalary;
  final double? allowance;
  final String? financialGoalText;
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.email,
    required this.preferredName,
    required this.preferredCurrency,
    this.monthlySalary,
    this.allowance,
    this.financialGoalText,
    this.isAdmin = false,
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
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'preferred_name': preferredName,
        'preferred_currency': preferredCurrency,
        'monthly_salary': monthlySalary,
        'allowance': allowance,
        'financial_goal_text': financialGoalText,
        'is_admin': isAdmin,
      };
}
