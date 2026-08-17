import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendlog_app/main.dart';
import 'package:spendlog_app/models/user.dart';
import 'package:spendlog_app/providers/auth_provider.dart';
import 'package:spendlog_app/router.dart';
import 'package:spendlog_app/screens/budgets_screen.dart';
import 'package:spendlog_app/screens/dashboard_screen.dart';
import 'package:spendlog_app/screens/expenses_screen.dart';
import 'package:spendlog_app/screens/profile_screen.dart';
import 'package:spendlog_app/utils/format.dart';

/// Compiles the entire widget graph (every screen is reachable from these
/// imports) and pins the pure helpers — a cheap tripwire until real widget
/// tests exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No stored token, so the startup restore settles into signed-out without
    // reaching for the keychain or the network.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

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

  test('an overspend is shown without its minus sign', () {
    // The API reports `remaining: "-6.00"` when over; the screens supply the
    // word "over", so the sign must not be printed as well.
    expect(moneyAbs('-6.00'), '\$6.00');
    expect(moneyAbs('6.00'), '\$6.00');
  });

  test('the router survives an auth change', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(routerProvider);
    await pumpEventQueue();

    container.read(authProvider.notifier).setUser(
          const User(
            uuid: 'u-1',
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            isAdmin: false,
          ),
        );
    await pumpEventQueue();

    // Rebuilding the router on an auth change re-applies `initialLocation`
    // and throws away all four tabs' navigation state — so saving a profile
    // would bounce the user back to the dashboard.
    expect(identical(before, container.read(routerProvider)), isTrue);
  });
}
