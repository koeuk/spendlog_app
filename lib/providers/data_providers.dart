import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/expense.dart';
import '../repositories/spendlog_repository.dart';
import '../utils/format.dart';

final repositoryProvider = Provider<SpendLogRepository>(
  (ref) => SpendLogRepository(ApiClient.instance),
);

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

class ExpensesState {
  const ExpensesState({required this.items, required this.hasMore, required this.page});

  final List<Expense> items;
  final bool hasMore;
  final int page;
}

class ExpensesNotifier extends AutoDisposeAsyncNotifier<ExpensesState> {
  @override
  Future<ExpensesState> build() async {
    final first = await ref.watch(repositoryProvider).expenses();

    return ExpensesState(items: first.items, hasMore: first.hasMore, page: 1);
  }

  /// Appends the next page; safe to call repeatedly from scroll callbacks.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    final next = await ref.read(repositoryProvider).expenses(page: current.page + 1);

    state = AsyncData(ExpensesState(
      items: [...current.items, ...next.items],
      hasMore: next.hasMore,
      page: current.page + 1,
    ));
  }
}

final expensesProvider =
    AsyncNotifierProvider.autoDispose<ExpensesNotifier, ExpensesState>(ExpensesNotifier.new);
