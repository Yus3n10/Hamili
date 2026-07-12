class AiInsight {
  final int id;
  final String insightType;
  final String message;
  final DateTime createdAt;

  const AiInsight({
    required this.id,
    required this.insightType,
    required this.message,
    required this.createdAt,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) => AiInsight(
        id: json['id'] as int,
        insightType: json['insight_type'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
