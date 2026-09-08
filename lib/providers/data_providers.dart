import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../models/expense_filters.dart';
import '../models/income.dart';
import '../models/report.dart';
import '../models/savings.dart';
import '../repositories/spendlog_repository.dart';
import '../utils/format.dart';

final repositoryProvider = Provider<SpendLogRepository>(
  (ref) => SpendLogRepository(ApiClient.instance),
);

// ------------------------------------------------------------------ reports

/// Which period the Reports screen is looking at: the granularity and the
/// anchor within it. Held together because changing the granularity has to
/// clear the anchor — '2026-08' means nothing to a year view.
class ReportPeriod {
  const ReportPeriod({this.granularity = 'month', this.anchor});

  final String granularity;

  /// Null means "the current one", which is what the server defaults to.
  final String? anchor;

  ReportPeriod withGranularity(String value) => ReportPeriod(granularity: value);

  ReportPeriod withAnchor(String value) =>
      ReportPeriod(granularity: granularity, anchor: value);
}

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => const ReportPeriod());

final reportProvider = FutureProvider.autoDispose<Report>((ref) {
  final period = ref.watch(reportPeriodProvider);

  return ref
      .watch(repositoryProvider)
      .report(period: period.granularity, at: period.anchor);
});

// ---------------------------------------------------------------- dashboard

/// Which month the dashboard is looking at. Applied to both budget and
/// breakdown, so the screen reads as one month, like flipping a page.
final dashboardMonthProvider = StateProvider<String>((ref) => currentYm());

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  final month = ref.watch(dashboardMonthProvider);

  return ref.watch(repositoryProvider).dashboard(month: month);
});

/// Which period the dashboard's spending chart covers.
///
/// Its own provider rather than a share of [reportPeriodProvider]: flipping the
/// dashboard chart to "All" should not rewrite what the Reports tab is showing
/// when you get there. Same reasoning that keeps [dashboardMonthProvider] and
/// [budgetsMonthProvider] apart.
///
/// Month to start, matching the web dashboard's own default.
final dashboardTrendProvider = StateProvider<String>((ref) => 'month');

/// The chart on the home screen. Always the current period — the dashboard is
/// "how am I doing now", so it sends no `at`; browsing back through history is
/// what the Reports tab is for.
final dashboardTrendReportProvider = FutureProvider.autoDispose<Report>(
  (ref) => ref
      .watch(repositoryProvider)
      .report(period: ref.watch(dashboardTrendProvider)),
);

// --------------------------------------------------------------- categories

final categoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(repositoryProvider).categories(),
);

// ------------------------------------------------------------------ budgets

final budgetsMonthProvider = StateProvider<String>((ref) => currentYm());

final budgetSummaryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(repositoryProvider).budgetSummary(ref.watch(budgetsMonthProvider)),
);

/// The stored rows for the month — the summary renders the screen, but only
/// these carry the uuid a delete needs.
final budgetRowsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(repositoryProvider).budgets(ref.watch(budgetsMonthProvider)),
);

// ----------------------------------------------------------------- expenses

final expenseFiltersProvider = StateProvider<ExpenseFilters>((ref) => const ExpenseFilters());

class ExpensesState {
  const ExpensesState({required this.items, required this.hasMore, required this.page});

  final List<Expense> items;
  final bool hasMore;
  final int page;
}

class ExpensesNotifier extends AutoDisposeAsyncNotifier<ExpensesState> {
  /// Guards against overlapping page fetches. The scroll listener fires many
  /// times per drag, and without this every one of those calls reads the same
  /// `page` and appends the same page of results.
  bool _loadingMore = false;

  @override
  Future<ExpensesState> build() async {
    _loadingMore = false;
    // Watched, so changing any filter rebuilds the list from page one.
    final filters = ref.watch(expenseFiltersProvider);
    final first = await ref.watch(repositoryProvider).expenses(filters: filters);

    return ExpensesState(items: first.items, hasMore: first.hasMore, page: 1);
  }

  /// Appends the next page. Safe to call repeatedly from scroll callbacks:
  /// extra calls while a fetch is in flight are dropped.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (_loadingMore || current == null || !current.hasMore) return;

    _loadingMore = true;

    try {
      final next = await ref.read(repositoryProvider).expenses(
            page: current.page + 1,
            filters: ref.read(expenseFiltersProvider),
          );

      state = AsyncData(ExpensesState(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
        page: current.page + 1,
      ));
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

final expensesProvider =
    AsyncNotifierProvider.autoDispose<ExpensesNotifier, ExpensesState>(ExpensesNotifier.new);

// ------------------------------------------------------------------ incomes

final incomeMonthProvider = StateProvider<String>((ref) => currentYm());

final incomeSummaryProvider = FutureProvider.autoDispose<IncomeSummary>(
  (ref) => ref.watch(repositoryProvider).incomeSummary(ref.watch(incomeMonthProvider)),
);

/// The month's rows. One page of 100 — the API's maximum — rather than a
/// paging notifier: a month with more than a hundred income entries is not a
/// case worth the machinery ExpensesNotifier carries.
final incomesProvider = FutureProvider.autoDispose<List<Income>>((ref) async {
  final bounds = monthBounds(ref.watch(incomeMonthProvider));
  final page = await ref
      .watch(repositoryProvider)
      .incomes(from: bounds.from, to: bounds.to, perPage: 100);

  return page.items;
});

// ------------------------------------------------------------------ savings

final savingsMonthProvider = StateProvider<String>((ref) => currentYm());

final savingsSummaryProvider = FutureProvider.autoDispose<SavingsSummary>(
  (ref) => ref.watch(repositoryProvider).savingsSummary(ref.watch(savingsMonthProvider)),
);

final savingsGoalsProvider = FutureProvider.autoDispose<List<SavingsGoal>>(
  (ref) => ref.watch(repositoryProvider).savingsGoals(),
);

/// One goal with its entries, for the detail screen.
final savingsGoalProvider = FutureProvider.autoDispose.family<SavingsGoal, String>(
  (ref, uuid) => ref.watch(repositoryProvider).savingsGoal(uuid),
);

/// Drops every savings figure a goal or entry write can move. The dashboard
/// carries the savings totals too, so it goes with them.
void invalidateSavings(WidgetRef ref) {
  ref
    ..invalidate(savingsGoalsProvider)
    ..invalidate(savingsSummaryProvider)
    ..invalidate(savingsGoalProvider)
    ..invalidate(dashboardProvider);
}

/// Same for income: the month's rows, its summary, and the dashboard's
/// income and balance lines.
void invalidateIncome(WidgetRef ref) {
  ref
    ..invalidate(incomesProvider)
    ..invalidate(incomeSummaryProvider)
    ..invalidate(dashboardProvider);
}

// ------------------------------------------------------------------- writes

/// Drops every cached figure that a write can move.
///
/// Each form used to name its own subset, and the five sets had already drifted
/// apart: saving an expense left the Reports tab showing totals from before it,
/// and nothing at all refreshed the dashboard's chart. One list means the next
/// money-derived provider is wired in exactly once, here, rather than in
/// however many forms happen to be remembered.
///
/// Deliberately blunt. These are all `autoDispose`, so invalidating a provider
/// no screen is watching costs nothing — and guessing which ones a given write
/// could not possibly have touched is how the sets drifted in the first place.
void invalidateMoney(WidgetRef ref) {
  ref
    ..invalidate(expensesProvider)
    ..invalidate(dashboardProvider)
    ..invalidate(dashboardTrendReportProvider)
    ..invalidate(budgetSummaryProvider)
    ..invalidate(budgetRowsProvider)
    ..invalidate(reportProvider)
    // An expense can create a category inline (`new_category`), so even an
    // expense write can change this list.
    ..invalidate(categoriesProvider);
}

// -------------------------------------------------------------------- admin

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>(
  (ref) => ref.watch(repositoryProvider).adminUsers(),
);

final faqsProvider = FutureProvider.autoDispose<List<FaqEntry>>(
  (ref) => ref.watch(repositoryProvider).faqs(),
);

final spendingSettingsProvider = FutureProvider.autoDispose<SpendingSettings>(
  (ref) => ref.watch(repositoryProvider).spendingSettings(),
);
