class AppCategory {
  final int id;
  final String name;
  final String type;
  final String? icon;

  const AppCategory({required this.id, required this.name, required this.type, this.icon});

  factory AppCategory.fromJson(Map<String, dynamic> json) => AppCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String?,
      );
}
