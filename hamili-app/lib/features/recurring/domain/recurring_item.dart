class RecurringItem {
  final int id;
  final String type;
  final String name;
  final double amount;
  final int categoryId;
  final String frequency;
  final DateTime nextDueDate;
  final bool active;

  const RecurringItem({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.nextDueDate,
    required this.active,
  });

  factory RecurringItem.fromJson(Map<String, dynamic> json) => RecurringItem(
        id: json['id'] as int,
        type: json['type'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryId: json['category_id'] as int,
        frequency: json['frequency'] as String,
        nextDueDate: DateTime.parse(json['next_due_date'] as String),
        active: json['active'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'amount': amount,
        'category_id': categoryId,
        'frequency': frequency,
        'next_due_date': nextDueDate.toIso8601String().split('T').first,
        'active': active,
      };
}
