import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:spendlog_app/providers/app_providers.dart';
import 'package:spendlog_app/providers/auth_provider.dart';
import 'package:spendlog_app/providers/branding_provider.dart';
import 'package:spendlog_app/providers/data_providers.dart';
import 'package:spendlog_app/providers/locale_provider.dart';
import 'package:spendlog_app/providers/theme_provider.dart';
import 'package:spendlog_app/repositories/spendlog_repository.dart';

/// The root wiring, checked without the screens.
///
/// Every notifier is declared in one list and most are proxied off the
/// repository, so a missing entry or one declared above what it reads is a
/// runtime throw on the screen that happens to want it — not something the
/// analyzer can catch. Resolving all of them here turns that into a test
/// failure instead.
void main() {
  Future<BuildContext> pumpProviders(WidgetTester tester) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MultiProvider(
        providers: appProviders(),
        child: Builder(
          builder: (context) {
            captured = context;

            return const SizedBox();
          },
        ),
      ),
    );

    return captured;
  }

  /// `AuthNotifier` holds the splash for three seconds at launch, so every
  /// test here starts a real timer. Letting it run out is what keeps the
  /// teardown from reporting a pending timer instead of the wiring result.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 4));

  testWidgets('every notifier resolves from the root', (tester) async {
    final context = await pumpProviders(tester);

    // Settings and identity.
    expect(context.read<LocaleNotifier>(), isNotNull);
    expect(context.read<ThemeModeNotifier>(), isNotNull);
    expect(context.read<AuthNotifier>(), isNotNull);
    expect(context.read<BrandingNotifier>(), isNotNull);
    expect(context.read<SpendLogRepository>(), isNotNull);

    // Screen state.
    expect(context.read<DashboardMonth>(), isNotNull);
    expect(context.read<DashboardTrend>(), isNotNull);
    expect(context.read<BudgetsMonth>(), isNotNull);
    expect(context.read<IncomeMonth>(), isNotNull);
    expect(context.read<SavingsMonth>(), isNotNull);
    expect(context.read<ReportPeriodNotifier>(), isNotNull);
    expect(context.read<ExpenseFiltersNotifier>(), isNotNull);
    expect(context.read<ActivityEveryone>(), isNotNull);

    // Data.
    expect(context.read<DashboardNotifier>(), isNotNull);
    expect(context.read<DashboardTrendReportNotifier>(), isNotNull);
    expect(context.read<ReportNotifier>(), isNotNull);
    expect(context.read<BudgetSummaryNotifier>(), isNotNull);
    expect(context.read<BudgetRowsNotifier>(), isNotNull);
    expect(context.read<ExpensesNotifier>(), isNotNull);
    expect(context.read<IncomeSummaryNotifier>(), isNotNull);
    expect(context.read<IncomesNotifier>(), isNotNull);
    expect(context.read<ActivityNotifier>(), isNotNull);
    expect(context.read<CategoriesNotifier>(), isNotNull);
    expect(context.read<MoneySettingsNotifier>(), isNotNull);
    expect(context.read<IncomeSourcesNotifier>(), isNotNull);
    expect(context.read<RecurringRulesNotifier>(), isNotNull);
    expect(context.read<SavingsSummaryNotifier>(), isNotNull);
    expect(context.read<SavingsEntriesNotifier>(), isNotNull);
    expect(context.read<SavingsPlanNotifier>(), isNotNull);

    // Admin.
    expect(context.read<AdminUsersNotifier>(), isNotNull);
    expect(context.read<FaqsNotifier>(), isNotNull);
    expect(context.read<SpendingSettingsNotifier>(), isNotNull);
    expect(context.read<BrandingSettingsNotifier>(), isNotNull);
    expect(context.read<ColorSettingsNotifier>(), isNotNull);

    await settle(tester);
  });

  testWidgets('the invalidate helpers reach every notifier they name', (
    tester,
  ) async {
    final context = await pumpProviders(tester);

    // These run from sheets after a save. Each reads a dozen notifiers by
    // type, so one missing from the list above throws at exactly the moment
    // the user has finished entering something.
    invalidateMoney(context);
    invalidateSavings(context);
    invalidateIncome(context);
    invalidateRecurring(context);

    await settle(tester);
  });

  testWidgets('a month change rebinds the notifier rather than replacing it', (
    tester,
  ) async {
    final context = await pumpProviders(tester);

    // Listing the month as a provider dependency re-runs the proxy's `update`
    // when it moves, which is what rebinds — but `update` must hand back the
    // notifier it was given. Building a fresh one there would drop the loaded
    // value and any listener a screen had attached, so the stepper would move
    // and the card beneath it would blank instead of refetching.
    final dashboard = context.read<DashboardNotifier>();

    context.read<DashboardMonth>().value = '2020-01';
    await tester.pump();

    expect(identical(context.read<DashboardNotifier>(), dashboard), isTrue);

    await settle(tester);
  });
}
