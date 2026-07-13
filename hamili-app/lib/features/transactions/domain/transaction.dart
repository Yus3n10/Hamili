class AppTransaction {
  final int id;
  final int categoryId;
  final double amount;
  final String type;
  final String? note;
  final DateTime transactionDate;

  const AppTransaction({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.transactionDate,
    this.note,
  });

  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
        id: json['id'] as int,
        categoryId: json['category_id'] as int,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] as String,
        note: json['note'] as String?,
        transactionDate: DateTime.parse(json['transaction_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
        'type': type,
        'note': note,
        'transaction_date': transactionDate.toIso8601String().split('T').first,
      };
}
