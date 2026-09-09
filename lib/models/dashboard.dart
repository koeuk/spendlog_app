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

/// The savings block on GET /dashboard — the all-time balance and the month
/// against its plan, so the home screen can show "$60.00 of $100.00 this
/// month" without a second call. Every key is optional: an older server, or
/// one that has yet to be migrated, simply reads as nothing planned.
class DashboardSavings {
  const DashboardSavings({
    required this.month,
    required this.planned,
    required this.savedThisMonth,
    required this.percent,
    required this.totalSaved,
  });

  /// `YYYY-MM`, following the request's `budget_month`.
  final String month;

  /// The month's plan, or "0.00" when none is set.
  final String planned;

  /// Deposits minus withdrawals dated within the month; may be negative.
  final String savedThisMonth;

  /// 0..100, already capped.
  final num percent;

  /// Every entry ever, all time.
  final String totalSaved;

  /// True once the month has a plan to measure against.
  bool get hasPlan => (double.tryParse(planned) ?? 0) > 0;

  factory DashboardSavings.fromJson(Map<String, dynamic> json) =>
      DashboardSavings(
        month: json['month'] as String? ?? '',
        planned: json['planned'] as String? ?? '0.00',
        savedThisMonth: json['saved_this_month'] as String? ?? '0.00',
        percent: json['percent'] as num? ?? 0,
        totalSaved: json['total_saved'] as String? ?? '0.00',
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
      incomeTotal: income is Map<String, dynamic>
          ? income['total'] as String?
          : null,
      balance: json['balance'] as String?,
      savings: savings is Map<String, dynamic>
          ? DashboardSavings.fromJson(savings)
          : null,
    );
  }
}
