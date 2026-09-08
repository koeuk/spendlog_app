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

/// The savings block on GET /dashboard — the totals across every goal, so
/// the home screen can show "$320 of $1,500" without a second call.
class DashboardSavings {
  const DashboardSavings({
    required this.totalSaved,
    required this.totalTarget,
    required this.percent,
    required this.goalsCount,
  });

  final String totalSaved;
  final String totalTarget;
  final num percent;
  final int goalsCount;

  factory DashboardSavings.fromJson(Map<String, dynamic> json) => DashboardSavings(
        totalSaved: json['total_saved'] as String? ?? '0.00',
        totalTarget: json['total_target'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        goalsCount: (json['goals_count'] as num?)?.toInt() ?? 0,
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
    this.incomeTotal,
    this.balance,
    this.savings,
  });

  final String todayDate;
  final String todayTotal;
  final String currentMonth;
  final BudgetSummary summary;
  final String budgetMonth;
  final List<BreakdownSlice> breakdown;
  final String breakdownMonth;
  final List<Expense> recent;

  /// The `income`, `balance` and `savings` blocks arrived with the Income and
  /// Savings features. All three are optional so a build talking to an older
  /// server still renders the rest of the dashboard — the cards that need
  /// them simply stay hidden.
  final String? incomeTotal;

  /// Income minus spent for the budget month; may be negative.
  final String? balance;

  final DashboardSavings? savings;

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final income = json['income'];
    final savings = json['savings'];

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
      incomeTotal: income is Map<String, dynamic> ? income['total'] as String? : null,
      balance: json['balance'] as String?,
      savings: savings is Map<String, dynamic> ? DashboardSavings.fromJson(savings) : null,
    );
  }
}
