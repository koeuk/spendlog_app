class Category {
  const Category({
    required this.uuid,
    required this.name,
    required this.color,
    this.icon,
    this.expensesCount,
  });

  final String uuid;
  final String name;
  final String color;
  final String? icon;
  final int? expensesCount;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        icon: json['icon'] as String?,
        expensesCount: json['expenses_count'] as int?,
      );
}
