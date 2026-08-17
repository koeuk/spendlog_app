import 'budget_summary.dart';
import 'expense.dart';

class BreakdownSlice {
  const BreakdownSlice({
    required this.uuid,
    required this.name,
    required this.color,
    required this.spent,
    required this.share,
  });

  final String uuid;
  final String name;
  final String color;
  final String spent;
  final num share;

  factory BreakdownSlice.fromJson(Map<String, dynamic> json) => BreakdownSlice(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'slate',
        spent: json['spent'] as String? ?? '0.00',
        share: json['share'] as num? ?? 0,
      );
}

/// Everything the home screen needs, from the one GET /dashboard call.
class Dashboard {
  const Dashboard({
    required this.todayDate,
    required this.todayTotal,
    required this.currentMonth,
    required this.summary,
    required this.budgetMonth,
    required this.breakdown,
    required this.breakdownMonth,
    required this.recent,
  });

  final String todayDate;
  final String todayTotal;
  final String currentMonth;
  final BudgetSummary summary;
  final String budgetMonth;
  final List<BreakdownSlice> breakdown;
  final String breakdownMonth;
  final List<Expense> recent;

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};

    return Dashboard(
      todayDate: today['date'] as String? ?? '',
      todayTotal: today['total'] as String? ?? '0.00',
      currentMonth: json['current_month'] as String? ?? '',
      summary: BudgetSummary.fromJson(json['summary'] as Map<String, dynamic>),
      budgetMonth: json['budget_month'] as String? ?? '',
      breakdown: (json['breakdown'] as List<dynamic>? ?? [])
          .map((e) => BreakdownSlice.fromJson(e as Map<String, dynamic>))
          .toList(),
      breakdownMonth: json['breakdown_month'] as String? ?? '',
      recent: (json['recent'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
