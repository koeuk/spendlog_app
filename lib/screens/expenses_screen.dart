import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/expense.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'expense_form_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Fetch the next page a screenful before the end, so scrolling never
      // visibly hits the bottom.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        ref.read(expensesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _delete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this expense?'),
        content: Text('${expense.item} — ${money(expense.price)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteExpense(expense.uuid);
      ref
        ..invalidate(expensesProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(budgetSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Expenses',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseForm(context),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(expensesProvider),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 44, color: Colors.black.withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  const Text('No expenses yet — add your first one.'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.green,
            onRefresh: () => refreshQuietly(ref.refresh(expensesProvider.future)),
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.green),
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
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                child: Icon(CategoryStyle.icon(expense.category?.icon),
                    size: 20, color: color),
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
                    Text(
                      [
                        if (expense.category != null) expense.category!.name,
                        if (expense.spentOn != null) dayLabel(expense.spentOn!),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money(expense.price),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
