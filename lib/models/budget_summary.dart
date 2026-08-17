/// One spend-vs-budget line, used for both the overall figure and each
/// category row. `budget` null means "no budget set" — different from "0.00".
class BudgetLine {
  const BudgetLine({
    required this.spent,
    required this.percent,
    required this.barPercent,
    required this.status,
    this.uuid,
    this.name,
    this.color,
    this.icon,
    this.budget,
    this.remaining,
  });

  final String spent;
  final num percent;

  /// Capped at 100 by the server so a bar cannot overflow its track;
  /// `percent` keeps the truth.
  final num barPercent;

  /// ok | warning | over | none
  final String status;

  final String? uuid;
  final String? name;
  final String? color;
  final String? icon;
  final String? budget;
  final String? remaining;

  factory BudgetLine.fromJson(Map<String, dynamic> json) => BudgetLine(
        spent: json['spent'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        barPercent: json['bar_percent'] as num? ?? 0,
        status: json['status'] as String? ?? 'none',
        uuid: json['uuid'] as String?,
        name: json['name'] as String?,
        color: json['color'] as String?,
        icon: json['icon'] as String?,
        budget: json['budget'] as String?,
        remaining: json['remaining'] as String?,
      );
}

class BudgetSummary {
  const BudgetSummary({
    required this.month,
    required this.overall,
    required this.categories,
  });

  final String month;
  final BudgetLine overall;
  final List<BudgetLine> categories;

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
        month: json['month'] as String? ?? '',
        overall: BudgetLine.fromJson(json['overall'] as Map<String, dynamic>),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => BudgetLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
