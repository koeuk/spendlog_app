import 'package:flutter/foundation.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../api/api_client.dart';
import '../router.dart';
import '../repositories/auth_repository.dart';
import '../repositories/spendlog_repository.dart';
import 'async_notifier.dart';
import 'auth_provider.dart';
import 'branding_provider.dart';
import 'data_providers.dart';
import 'locale_provider.dart';
import 'theme_provider.dart';

/// Every provider in the app, in one list, wrapped around the root in
/// `main.dart`.
///
/// One list rather than a scope per screen: `provider` resolves by type
/// through the element tree, so a notifier declared above a route is the same
/// instance for every screen below it — which is what lets a sheet invalidate
/// a list it cannot see. Nothing here is expensive to hold: an [AsyncNotifier]
/// that no screen has read is an object with a `_needsLoad` boolean and no
/// request behind it.
///
/// Order matters. A provider may only read ones declared above it, so this
/// runs inputs first (the language, the screens' months and filters), then the
/// repositories built from them, then the notifiers that call through those.
List<SingleChildWidget> appProviders() => [
  // ------------------------------------------------------------- settings

  ChangeNotifierProvider(create: (_) => LocaleNotifier()),
  ChangeNotifierProvider(create: (_) => ThemeModeNotifier()),

  // --------------------------------------------------------- repositories

  // Rebuilt when the language changes, and that new instance is the signal:
  // `bind` compares identity, so every data notifier treats a different
  // repository as "what I cached was fetched in the old language" and drops
  // it. Category names, FAQs and guidance copy all come back translated.
  ProxyProvider<LocaleNotifier, SpendLogRepository>(
    update: (_, _, _) => SpendLogRepository(ApiClient.instance),
  ),
  // Not locale-dependent: nothing it returns is translated server-side.
  Provider(create: (_) => AuthRepository(ApiClient.instance)),

  // ------------------------------------------------------------- identity

  // Eager: its constructor starts the token restore, and the splash is
  // waiting on the result. Lazily created it would not begin until the first
  // screen read it, which is the screen that cannot be chosen until it has.
  ChangeNotifierProvider(
    create: (context) => AuthNotifier(context.read<AuthRepository>()),
    lazy: false,
  ),

  // Eager for the same reason on the other side: the theme is built from it,
  // so waiting for a read would paint the stock look and then flip.
  ChangeNotifierProxyProvider<SpendLogRepository, BrandingNotifier>(
    create: (_) => BrandingNotifier(),
    update: (_, repository, notifier) => notifier!..bind(repository),
    lazy: false,
  ),

  // Built from [AuthNotifier], and exactly once: `create` rather than an
  // `update`, because handing `MaterialApp.router` a new GoRouter re-applies
  // `initialLocation` and resets every tab (see [buildRouter]).
  Provider<GoRouter>(
    create: (context) => buildRouter(context.read<AuthNotifier>()),
    dispose: (_, router) => router.dispose(),
  ),

  // ------------------------------------------------- what the screens pick

  // Each screen's own month, kept apart on purpose: stepping the dashboard
  // back a month should not move what Budgets or Savings are showing.
  ChangeNotifierProvider(create: (_) => DashboardMonth()),
  ChangeNotifierProvider(create: (_) => DashboardTrend()),
  ChangeNotifierProvider(create: (_) => BudgetsMonth()),
  ChangeNotifierProvider(create: (_) => IncomeMonth()),
  ChangeNotifierProvider(create: (_) => SavingsMonth()),
  ChangeNotifierProvider(create: (_) => ReportPeriodNotifier()),
  ChangeNotifierProvider(create: (_) => ExpenseFiltersNotifier()),
  ChangeNotifierProvider(create: (_) => ActivityEveryone()),

  // ------------------------------------------------------------ money data
  _boundTo<DashboardMonth, DashboardNotifier>(DashboardNotifier.new),
  _boundTo<DashboardTrend, DashboardTrendReportNotifier>(
    DashboardTrendReportNotifier.new,
  ),
  _boundTo<ReportPeriodNotifier, ReportNotifier>(ReportNotifier.new),
  _boundTo<BudgetsMonth, BudgetSummaryNotifier>(BudgetSummaryNotifier.new),
  _boundTo<BudgetsMonth, BudgetRowsNotifier>(BudgetRowsNotifier.new),
  _boundTo<ExpenseFiltersNotifier, ExpensesNotifier>(ExpensesNotifier.new),
  _boundTo<IncomeMonth, IncomeSummaryNotifier>(IncomeSummaryNotifier.new),
  _boundTo<IncomeMonth, IncomesNotifier>(IncomesNotifier.new),
  _boundTo<ActivityEveryone, ActivityNotifier>(ActivityNotifier.new),

  _bound(CategoriesNotifier.new),
  _bound(MoneySettingsNotifier.new),
  _bound(IncomeSourcesNotifier.new),
  _bound(RecurringRulesNotifier.new),

  // Keyed by month, so a sheet can ask about a month the screen is not on.
  _boundFamily(SavingsSummaryNotifier.new),
  _boundFamily(SavingsEntriesNotifier.new),
  _boundFamily(SavingsPlanNotifier.new),

  // ---------------------------------------------------------------- admin
  _bound(AdminUsersNotifier.new),
  _bound(FaqsNotifier.new),
  _bound(SpendingSettingsNotifier.new),
  _bound(BrandingSettingsNotifier.new),
  _bound(ColorSettingsNotifier.new),
];

/// A notifier whose fetch needs nothing but the repository.
///
/// `update` fires on every rebuild of the repository — which only happens when
/// the language changes — and [AsyncNotifier.bind] decides from there whether
/// anything cached is still good.
ChangeNotifierProxyProvider<SpendLogRepository, N>
_bound<N extends AsyncNotifier<Object?>>(N Function() create) =>
    ChangeNotifierProxyProvider<SpendLogRepository, N>(
      create: (_) => create(),
      update: (_, repository, notifier) => notifier!..bind(repository),
    );

/// A notifier that also reads one piece of screen state — a month, a filter
/// set — named as [D].
///
/// [D] is a dependency of the *provider*, not just of the notifier: listing it
/// is what re-runs `update` when that state changes, and `bind` comparing
/// `dependencies` there is what marks the cached value stale. Without it a
/// month step would move the stepper and leave the figures beneath it.
///
/// The notifier is handed the state object once, at creation, and reads its
/// current value on each fetch — so this only has to fire, not carry anything.
ChangeNotifierProxyProvider2<SpendLogRepository, D, N>
_boundTo<D extends ChangeNotifier, N extends AsyncNotifier<Object?>>(
  N Function(D dependency) create,
) => ChangeNotifierProxyProvider2<SpendLogRepository, D, N>(
  create: (context) => create(context.read<D>()),
  update: (_, repository, _, notifier) => notifier!..bind(repository),
);

/// The keyed twin of [_bound]: one notifier holding a value per key.
ChangeNotifierProxyProvider<SpendLogRepository, N> _boundFamily<
  N extends FamilyAsyncNotifier<Object?, Object?>
>(N Function() create) => ChangeNotifierProxyProvider<SpendLogRepository, N>(
  create: (_) => create(),
  update: (_, repository, notifier) => notifier!..bind(repository),
);
