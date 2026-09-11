import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/activity.dart';
import '../models/admin.dart';
import '../models/budget.dart';
import '../models/budget_summary.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../models/expense_filters.dart';
import '../models/income.dart';
import '../models/money_settings.dart';
import '../models/recurring.dart';
import '../models/report.dart';
import '../models/savings.dart';
import '../utils/format.dart';
import 'async_notifier.dart';

// ------------------------------------------------------------------ reports

/// Which period the Reports screen is looking at: the granularity and the
/// anchor within it. Held together because changing the granularity has to
/// clear the anchor — '2026-08' means nothing to a year view.
class ReportPeriod {
  const ReportPeriod({this.granularity = 'month', this.anchor});

  final String granularity;

  /// Null means "the current one", which is what the server defaults to.
  final String? anchor;

  ReportPeriod withGranularity(String value) =>
      ReportPeriod(granularity: value);

  ReportPeriod withAnchor(String value) =>
      ReportPeriod(granularity: granularity, anchor: value);
}

class ReportPeriodNotifier extends ValueState<ReportPeriod> {
  ReportPeriodNotifier() : super(const ReportPeriod());
}

class ReportNotifier extends AsyncNotifier<Report> {
  ReportNotifier(this._period);

  final ReportPeriodNotifier _period;

  @override
  List<Object?> get dependencies => [_period.value];

  @override
  Future<Report> fetch() => repository.report(
    period: _period.value.granularity,
    at: _period.value.anchor,
  );
}

// ---------------------------------------------------------------- dashboard

/// Which month the dashboard is looking at. Applied to both budget and
/// breakdown, so the screen reads as one month, like flipping a page.
class DashboardMonth extends ValueState<String> {
  DashboardMonth() : super(currentYm());
}

class DashboardNotifier extends AsyncNotifier<Dashboard> {
  DashboardNotifier(this._month);

  final DashboardMonth _month;

  @override
  List<Object?> get dependencies => [_month.value];

  @override
  Future<Dashboard> fetch() => repository.dashboard(month: _month.value);
}

/// Which period the dashboard's spending chart covers.
///
/// Its own state rather than a share of [ReportPeriodNotifier]: flipping the
/// dashboard chart to "All" should not rewrite what the Reports tab is showing
/// when you get there. Same reasoning that keeps [DashboardMonth] and
/// [BudgetsMonth] apart.
///
/// Month to start, matching the web dashboard's own default.
class DashboardTrend extends ValueState<String> {
  DashboardTrend() : super('month');
}

/// The chart on the home screen. Always the current period — the dashboard is
/// "how am I doing now", so it sends no `at`; browsing back through history is
/// what the Reports tab is for.
class DashboardTrendReportNotifier extends AsyncNotifier<Report> {
  DashboardTrendReportNotifier(this._trend);

  final DashboardTrend _trend;

  @override
  List<Object?> get dependencies => [_trend.value];

  @override
  Future<Report> fetch() => repository.report(period: _trend.value);
}

// --------------------------------------------------------------- categories

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> fetch() => repository.categories();
}

// ------------------------------------------------------------------ budgets

class BudgetsMonth extends ValueState<String> {
  BudgetsMonth() : super(currentYm());
}

class BudgetSummaryNotifier extends AsyncNotifier<BudgetSummary> {
  BudgetSummaryNotifier(this._month);

  final BudgetsMonth _month;

  @override
  List<Object?> get dependencies => [_month.value];

  @override
  Future<BudgetSummary> fetch() => repository.budgetSummary(_month.value);
}

/// The stored rows for the month — the summary renders the screen, but only
/// these carry the uuid a delete needs.
class BudgetRowsNotifier extends AsyncNotifier<List<Budget>> {
  BudgetRowsNotifier(this._month);

  final BudgetsMonth _month;

  @override
  List<Object?> get dependencies => [_month.value];

  @override
  Future<List<Budget>> fetch() => repository.budgets(_month.value);
}

// ----------------------------------------------------------------- expenses

class ExpenseFiltersNotifier extends ValueState<ExpenseFilters> {
  ExpenseFiltersNotifier() : super(const ExpenseFilters());
}

class ExpensesState {
  const ExpensesState({
    required this.items,
    required this.hasMore,
    required this.page,
  });

  final List<Expense> items;
  final bool hasMore;
  final int page;
}

class ExpensesNotifier extends AsyncNotifier<ExpensesState> {
  ExpensesNotifier(this._filters);

  final ExpenseFiltersNotifier _filters;

  /// Guards against overlapping page fetches. The scroll listener fires many
  /// times per drag, and without this every one of those calls reads the same
  /// `page` and appends the same page of results.
  bool _loadingMore = false;

  /// Depended on, so changing any filter rebuilds the list from page one.
  @override
  List<Object?> get dependencies => [_filters.value];

  @override
  Future<ExpensesState> fetch() async {
    _loadingMore = false;
    final first = await repository.expenses(filters: _filters.value);

    return ExpensesState(items: first.items, hasMore: first.hasMore, page: 1);
  }

  /// Appends the next page. Safe to call repeatedly from scroll callbacks:
  /// extra calls while a fetch is in flight are dropped.
  Future<void> loadMore() async {
    final loaded = current.valueOrNull;
    if (_loadingMore || loaded == null || !loaded.hasMore) return;

    _loadingMore = true;

    try {
      final next = await repository.expenses(
        page: loaded.page + 1,
        filters: _filters.value,
      );

      emit(
        AsyncState.data(
          ExpensesState(
            items: [...loaded.items, ...next.items],
            hasMore: next.hasMore,
            page: loaded.page + 1,
          ),
        ),
      );
    } catch (_) {
      // Callers are scroll callbacks that cannot await this, so an escaping
      // error would surface as an unhandled exception. Swallowing keeps the
      // pages already on screen; the next scroll retries, and pull-to-refresh
      // reports the failure properly.
    } finally {
      _loadingMore = false;
    }
  }
}

// ------------------------------------------------------------------ incomes

/// The exchange rate and default currency. Every amount field reads it, and
/// it changes about never.
class MoneySettingsNotifier extends AsyncNotifier<MoneySettings> {
  @override
  Future<MoneySettings> fetch() => repository.moneySettings();
}

class IncomeMonth extends ValueState<String> {
  IncomeMonth() : super(currentYm());
}

class IncomeSourcesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> fetch() => repository.incomeSources();
}

class IncomeSummaryNotifier extends AsyncNotifier<IncomeSummary> {
  IncomeSummaryNotifier(this._month);

  final IncomeMonth _month;

  @override
  List<Object?> get dependencies => [_month.value];

  @override
  Future<IncomeSummary> fetch() => repository.incomeSummary(_month.value);
}

/// The month's rows. One page of 100 — the API's maximum — rather than a
/// paging notifier: a month with more than a hundred income entries is not a
/// case worth the machinery [ExpensesNotifier] carries.
class IncomesNotifier extends AsyncNotifier<List<Income>> {
  IncomesNotifier(this._month);

  final IncomeMonth _month;

  @override
  List<Object?> get dependencies => [_month.value];

  @override
  Future<List<Income>> fetch() async {
    final bounds = monthBounds(_month.value);
    final page = await repository.incomes(
      from: bounds.from,
      to: bounds.to,
      perPage: 100,
    );

    return page.items;
  }
}

// ------------------------------------------------------------------ savings

class SavingsMonth extends ValueState<String> {
  SavingsMonth() : super(currentYm());
}

/// Keyed by month rather than reading [SavingsMonth] itself, so the sheets can
/// ask for a month without the screen's state getting in the way.
class SavingsSummaryNotifier
    extends FamilyAsyncNotifier<SavingsSummary, String> {
  @override
  Future<SavingsSummary> fetch(String month) =>
      repository.savingsSummary(month);
}

class SavingsEntriesNotifier
    extends FamilyAsyncNotifier<List<SavingsEntry>, String> {
  @override
  Future<List<SavingsEntry>> fetch(String month) =>
      repository.savingsEntries(month);
}

/// The stored plan row, for its uuid — Clear needs one to delete.
class SavingsPlanNotifier extends FamilyAsyncNotifier<SavingsPlan?, String> {
  @override
  Future<SavingsPlan?> fetch(String month) => repository.savingsPlan(month);
}

// ---------------------------------------------------------------- recurring

/// Every rule of both kinds; the screen filters by kind itself, so flipping
/// the segment costs no request.
class RecurringRulesNotifier extends AsyncNotifier<List<RecurringRule>> {
  @override
  Future<List<RecurringRule>> fetch() => repository.recurringRules();
}

// ----------------------------------------------------------------- activity

/// Whether an admin is looking at everyone's log rather than their own.
class ActivityEveryone extends ValueState<bool> {
  ActivityEveryone() : super(false);
}

class ActivityState {
  const ActivityState({
    required this.items,
    required this.hasMore,
    required this.page,
  });

  final List<ActivityEntry> items;
  final bool hasMore;
  final int page;
}

class ActivityNotifier extends AsyncNotifier<ActivityState> {
  ActivityNotifier(this._everyone);

  final ActivityEveryone _everyone;

  bool _loadingMore = false;

  /// Depended on, so flipping the scope rebuilds from page one.
  @override
  List<Object?> get dependencies => [_everyone.value];

  @override
  Future<ActivityState> fetch() async {
    _loadingMore = false;
    final first = await repository.activity(everyone: _everyone.value);

    return ActivityState(items: first.items, hasMore: first.hasMore, page: 1);
  }

  Future<void> loadMore() async {
    final loaded = current.valueOrNull;
    if (_loadingMore || loaded == null || !loaded.hasMore) return;

    _loadingMore = true;

    try {
      final next = await repository.activity(
        page: loaded.page + 1,
        everyone: _everyone.value,
      );

      emit(
        AsyncState.data(
          ActivityState(
            items: [...loaded.items, ...next.items],
            hasMore: next.hasMore,
            page: loaded.page + 1,
          ),
        ),
      );
    } catch (_) {
      // Same reasoning as ExpensesNotifier.loadMore: scroll callbacks cannot
      // await, so failures keep the loaded pages and the next scroll retries.
    } finally {
      _loadingMore = false;
    }
  }
}

// -------------------------------------------------------------------- admin

class AdminUsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> fetch() => repository.adminUsers();
}

class FaqsNotifier extends AsyncNotifier<List<FaqEntry>> {
  @override
  Future<List<FaqEntry>> fetch() => repository.faqs();
}

class SpendingSettingsNotifier extends AsyncNotifier<SpendingSettings> {
  @override
  Future<SpendingSettings> fetch() => repository.spendingSettings();
}

class BrandingSettingsNotifier extends AsyncNotifier<BrandingSettings> {
  @override
  Future<BrandingSettings> fetch() => repository.brandingSettings();
}

class ColorSettingsNotifier extends AsyncNotifier<ColorSettings> {
  @override
  Future<ColorSettings> fetch() => repository.colorSettings();
}

// ------------------------------------------------------------------- writes

/// Drops every cached figure that a write can move.
///
/// Each form used to name its own subset, and the five sets had already drifted
/// apart: saving an expense left the Reports tab showing totals from before it,
/// and nothing at all refreshed the dashboard's chart. One list means the next
/// money-derived notifier is wired in exactly once, here, rather than in
/// however many forms happen to be remembered.
///
/// Deliberately blunt. Invalidating only marks the value stale — the fetch
/// happens when a screen next reads it — so naming a notifier nothing is
/// watching costs a boolean, and guessing which ones a given write could not
/// possibly have touched is how the sets drifted in the first place.
void invalidateMoney(BuildContext context) => moneyInvalidator(context)();

/// [invalidateMoney], captured now and fired later.
///
/// A form has to invalidate *after* its write lands, which is after an await —
/// and by then its sheet may have been dragged away, leaving a `BuildContext`
/// that throws on `read`. Riverpod's `ref` outlived that; a context does not.
/// So forms capture the call before the write and fire it after, and the
/// figures refresh whether or not the sheet is still up.
VoidCallback moneyInvalidator(BuildContext context) => _all([
  context.read<ExpensesNotifier>().invalidate,
  context.read<DashboardNotifier>().invalidate,
  context.read<DashboardTrendReportNotifier>().invalidate,
  context.read<BudgetSummaryNotifier>().invalidate,
  context.read<BudgetRowsNotifier>().invalidate,
  context.read<ReportNotifier>().invalidate,
  // An expense can create a category inline (`new_category`), so even an
  // expense write can change this list.
  context.read<CategoriesNotifier>().invalidate,
]);

/// Drops every savings figure a plan or entry write can move. The dashboard
/// carries the savings totals too, so it goes with them.
void invalidateSavings(BuildContext context) => savingsInvalidator(context)();

/// [invalidateSavings], captured now and fired later — see [moneyInvalidator].
VoidCallback savingsInvalidator(BuildContext context) => _all([
  // The keyed three drop every month they hold: a deposit dated back into
  // August moves August's figures, not only the month on screen.
  context.read<SavingsSummaryNotifier>().invalidate,
  context.read<SavingsEntriesNotifier>().invalidate,
  context.read<SavingsPlanNotifier>().invalidate,
  context.read<DashboardNotifier>().invalidate,
]);

/// Same for income: the month's rows, its summary, and the dashboard's
/// income and balance lines.
void invalidateIncome(BuildContext context) => incomeInvalidator(context)();

/// [invalidateIncome], captured now and fired later — see [moneyInvalidator].
VoidCallback incomeInvalidator(BuildContext context) => _all([
  context.read<IncomesNotifier>().invalidate,
  context.read<IncomeSummaryNotifier>().invalidate,
  // A save can introduce a source the picker has not offered before.
  context.read<IncomeSourcesNotifier>().invalidate,
  context.read<DashboardNotifier>().invalidate,
]);

/// Drops the rules and every figure a rule write can move. Saving a rule
/// runs it at once server-side, so a rule starting today has already put an
/// expense or income row on the books by the time the sheet closes.
void invalidateRecurring(BuildContext context) =>
    recurringInvalidator(context)();

/// [invalidateRecurring], captured now and fired later — see
/// [moneyInvalidator].
VoidCallback recurringInvalidator(BuildContext context) => _all([
  context.read<RecurringRulesNotifier>().invalidate,
  context.read<DashboardNotifier>().invalidate,
  context.read<DashboardTrendReportNotifier>().invalidate,
  context.read<ExpensesNotifier>().invalidate,
  context.read<IncomesNotifier>().invalidate,
  context.read<IncomeSummaryNotifier>().invalidate,
  context.read<BudgetSummaryNotifier>().invalidate,
  context.read<BudgetRowsNotifier>().invalidate,
  context.read<ReportNotifier>().invalidate,
]);

/// Fires a captured set in order. The keyed notifiers' `invalidate` takes an
/// optional key, which is why this holds plain [VoidCallback]s rather than
/// the notifiers themselves — calling one with no key drops every key it has.
VoidCallback _all(List<VoidCallback> calls) => () {
  for (final call in calls) {
    call();
  }
};
