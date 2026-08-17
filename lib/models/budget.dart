import 'category.dart';

/// A stored budget row: one (category, month) slot. A null category is the
/// overall budget covering everything.
class Budget {
  const Budget({
    required this.uuid,
    required this.amount,
    required this.month,
    this.category,
  });

  final String uuid;
  final String amount;
  final String month;
  final Category? category;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        uuid: json['uuid'] as String,
        amount: json['amount'] as String? ?? '0.00',
        month: json['month'] as String? ?? '',
        category: json['category'] is Map<String, dynamic>
            ? Category.fromJson(json['category'] as Map<String, dynamic>)
            : null,
      );
}
