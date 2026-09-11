import 'dart:async';

import '../l10n/l10n.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/expense.dart';
import '../models/expense_filters.dart';
import '../providers/async_notifier.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'expense_form_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Fetch the next page a screenful before the end, so scrolling never
      // visibly hits the bottom.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        context.read<ExpensesNotifier>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounced: one request when the typing pauses, not one per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final trimmed = value.trim();
      context.read<ExpenseFiltersNotifier>().update(
        (f) => f.copyWith(search: () => trimmed.isEmpty ? null : trimmed),
      );
    });
  }

  Future<void> _pickDateRange() async {
    // Read before the picker: `context` must not be touched across an await.
    final filterState = context.read<ExpenseFiltersNotifier>();
    final filters = filterState.value;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: filters.from != null && filters.to != null
          ? DateTimeRange(
              start: DateTime.parse(filters.from!),
              end: DateTime.parse(filters.to!),
            )
          : null,
    );

    if (picked == null) return;

    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    filterState.update(
      (f) =>
          f.copyWith(from: () => day(picked.start), to: () => day(picked.end)),
    );
  }

  Future<void> _delete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Delete this expense?')),
        content: Text('${expense.item} — ${money(expense.price)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Both captured before the delete: `context` must not be touched across an
    // await, and the refresh must still land if this screen is gone by then.
    final repository = context.read<SpendLogRepository>();
    final refresh = moneyInvalidator(context);

    try {
      await repository.deleteExpense(expense.uuid);
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpensesNotifier>().state;
    final filters = context.watch<ExpenseFiltersNotifier>().value;

    return Scaffold(
      appBar: AppBar(
        // A tab root with no back arrow: the title starts the line, the way
        // a list heading does. Pushed pages centre theirs between the arrow
        // and the actions.
        centerTitle: false,
        title: Text(tr('Expenses')),
      ),
      floatingActionButton: AddPill(
        label: tr('Add'),
        onPressed: () => showExpenseForm(context),
      ),
      body: Column(
        children: [
          _FilterBar(
            search: _search,
            filters: filters,
            onSearchChanged: _onSearchChanged,
            onPickDates: _pickDateRange,
          ),
          Expanded(child: _buildList(expenses, filters)),
        ],
      ),
    );
  }

  Widget _buildList(
    AsyncState<ExpensesState> expenses,
    ExpenseFilters filters,
  ) {
    return expenses.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.accent(context)),
      ),
      error: (e, _) => LoadFailed(
        message: apiErrorMessage(e),
        onRetry: () => context.read<ExpensesNotifier>().invalidate(),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 44,
                  color: AppTheme.faint(context, 0.25),
                ),
                const SizedBox(height: 12),
                Text(
                  filters.active
                      ? 'Nothing matches these filters.'
                      : 'No expenses yet — add your first one.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppTheme.accent(context),
          // `refresh` never throws — see AsyncNotifier.refresh.
          onRefresh: () => context.read<ExpensesNotifier>().refresh(),
          child: ListView.separated(
            controller: _scroll,
            // Clears the floating nav bar and the FAB stacked above it.
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= state.items.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent(context),
                      ),
                    ),
                  ),
                );
              }

              final expense = state.items[index];

              return _ExpenseTile(
                expense: expense,
                onTap: () => showExpenseForm(context, expense: expense),
                onDelete: () => _delete(expense),
              );
            },
          ),
        );
      },
    );
  }
}

/// Search box plus one scrolling row of chips: every category, the date
/// range, and — while anything is active — a clear-all.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.filters,
    required this.onSearchChanged,
    required this.onPickDates,
  });

  final TextEditingController search;
  final ExpenseFilters filters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context) {
    final categories =
        context.watch<CategoriesNotifier>().state.valueOrNull ?? [];
    final notifier = context.read<ExpenseFiltersNotifier>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        4,
        AppTheme.pageInset,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 46,
            child: TextField(
              controller: search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: tr('Search expenses…'),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: EdgeInsets.zero,
                suffixIcon: search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          search.clear();
                          notifier.update(
                            (f) => f.copyWith(search: () => null),
                          );
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ActionChip(
                        avatar: Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: filters.from != null
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        label: Text(
                          filters.from != null
                              ? '${dayLabel(filters.from!)} – ${dayLabel(filters.to!)}'
                              : 'Dates',
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          color: filters.from != null
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        backgroundColor: filters.from != null
                            ? AppTheme.accent(context)
                            : AppTheme.glassFill(context),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: AppTheme.faint(context, 0.10)),
                        onPressed: onPickDates,
                      ),
                      const SizedBox(width: 8),
                      for (final category in categories) ...[
                        FilterChip(
                          selected: filters.categoryUuid == category.uuid,
                          showCheckmark: false,
                          avatar: Icon(
                            CategoryStyle.icon(category.icon),
                            size: 15,
                            color: filters.categoryUuid == category.uuid
                                ? Colors.white
                                : CategoryStyle.color(category.color),
                          ),
                          label: Text(category.name),
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: filters.categoryUuid == category.uuid
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          selectedColor: CategoryStyle.color(category.color),
                          backgroundColor: AppTheme.glassFill(context),
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: AppTheme.faint(context, 0.10),
                          ),
                          onSelected: (selected) => notifier.update(
                            (f) => f.copyWith(
                              categoryUuid: () =>
                                  selected ? category.uuid : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                // Pinned beside the scrolling chips rather than trailing them.
                // As the row's last child it sat past every category, so the one
                // control that undoes a filter was itself hidden behind that
                // filter — exactly when you most need it.
                if (filters.active) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.filter_alt_off_outlined,
                      size: 15,
                      color: Color(0xFFDC2626),
                    ),
                    label: Text(tr('Clear')),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFDC2626),
                    ),
                    backgroundColor: AppTheme.glassFill(context),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: AppTheme.faint(context, 0.10)),
                    onPressed: () {
                      search.clear();
                      notifier.value = const ExpenseFilters();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(expense.category?.color);

    return Card(
      shape: AppTheme.rowShape(context),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppTheme.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CategoryStyle.icon(expense.category?.icon),
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              if (expense.category != null)
                                expense.category!.name,
                              if (expense.spentOn != null)
                                dayLabel(expense.spentOn!),
                            ].join(' · '),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.faint(context, 0.45),
                            ),
                          ),
                        ),
                        // Made by a recurring rule, not typed in.
                        if (expense.recurring) ...[
                          const SizedBox(width: 5),
                          Icon(
                            Icons.repeat,
                            size: 14,
                            color: AppTheme.faint(context, 0.4),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                money(expense.price),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
