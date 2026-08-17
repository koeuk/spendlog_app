import 'category.dart';

/// The list's filters, mirroring the API's filter[...] params. Null means
/// "not filtering by this" — never an empty string, which the API would take
/// as a real value to match.
class ExpenseFilters {
  const ExpenseFilters({this.search, this.categoryUuid, this.from, this.to});

  final String? search;
  final String? categoryUuid;
  final String? from;
  final String? to;

  bool get active => search != null || categoryUuid != null || from != null || to != null;

  /// Setters are thunks so a caller can distinguish "leave it" (omit) from
  /// "clear it" (`() => null`) — a plain nullable parameter cannot say both.
  ExpenseFilters copyWith({
    String? Function()? search,
    String? Function()? categoryUuid,
    String? Function()? from,
    String? Function()? to,
  }) =>
      ExpenseFilters(
        search: search != null ? search() : this.search,
        categoryUuid: categoryUuid != null ? categoryUuid() : this.categoryUuid,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
      );
}

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
