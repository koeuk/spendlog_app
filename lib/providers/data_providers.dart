import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../models/expense_filters.dart';
import '../models/report.dart';
import '../models/workout.dart';
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

// ----------------------------------------------------------------- workouts

final workoutMonthProvider = StateProvider<String>((ref) => currentYm());

final workoutSummaryProvider = FutureProvider.autoDispose<WorkoutSummary>(
  (ref) => ref
      .watch(repositoryProvider)
      .workoutSummary(month: ref.watch(workoutMonthProvider)),
);

final exercisesProvider = FutureProvider.autoDispose<List<ExerciseType>>(
  (ref) => ref.watch(repositoryProvider).exercises(),
);

class WorkoutsState {
  const WorkoutsState({required this.items, required this.hasMore, required this.page});

  final List<Workout> items;
  final bool hasMore;
  final int page;
}

class WorkoutsNotifier extends AutoDisposeAsyncNotifier<WorkoutsState> {
  bool _loadingMore = false;

  @override
  Future<WorkoutsState> build() async {
    _loadingMore = false;
    final first = await ref.watch(repositoryProvider).workouts();

    return WorkoutsState(items: first.items, hasMore: first.hasMore, page: 1);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (_loadingMore || current == null || !current.hasMore) return;

    _loadingMore = true;

    try {
      final next = await ref.read(repositoryProvider).workouts(page: current.page + 1);

      state = AsyncData(WorkoutsState(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
        page: current.page + 1,
      ));
    } catch (_) {
      // Same reasoning as ExpensesNotifier.loadMore: scroll callbacks cannot
      // await, so failures keep the loaded pages and the next scroll retries.
    } finally {
      _loadingMore = false;
    }
  }
}

final workoutsProvider =
    AsyncNotifierProvider.autoDispose<WorkoutsNotifier, WorkoutsState>(WorkoutsNotifier.new);
