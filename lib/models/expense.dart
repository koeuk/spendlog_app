import 'category.dart';

class Expense {
  const Expense({
    required this.uuid,
    required this.item,
    required this.price,
    this.spentOn,
    this.category,
  });

  final String uuid;
  final String item;

  /// Money is a string ("12.50") end to end — see the API doc's money note.
  final String price;

  final String? spentOn;
  final Category? category;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        uuid: json['uuid'] as String,
        item: json['item'] as String? ?? '',
        price: json['price'] as String? ?? '0.00',
        spentOn: json['spent_on'] as String?,
        category: json['category'] is Map<String, dynamic>
            ? Category.fromJson(json['category'] as Map<String, dynamic>)
            : null,
      );
}
