import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_app/main.dart';
import 'package:spendlog_app/screens/budgets_screen.dart';
import 'package:spendlog_app/screens/dashboard_screen.dart';
import 'package:spendlog_app/screens/expenses_screen.dart';
import 'package:spendlog_app/screens/profile_screen.dart';
import 'package:spendlog_app/utils/format.dart';

/// Compiles the entire widget graph (every screen is reachable from these
/// imports) and pins the pure helpers — a cheap tripwire until real widget
/// tests exist.
void main() {
  test('app graph compiles', () {
    expect(const SpendLogApp(), isNotNull);
    expect(const DashboardScreen(), isNotNull);
    expect(const ExpensesScreen(), isNotNull);
    expect(const BudgetsScreen(), isNotNull);
    expect(const ProfileScreen(), isNotNull);
  });

  test('month helpers speak the API format', () {
    expect(monthLabel('2026-08'), 'August 2026');
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-12', 1), '2027-01');
    expect(dayLabel('2026-08-17'), 'Aug 17');
    expect(money('12.50'), '\$12.50');
  });
}
