import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/budget_summary.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetsMonthProvider);
    final summary = ref.watch(budgetSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Budgets',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          MonthStepper(
            label: monthLabel(month),
            onPrevious: () =>
                ref.read(budgetsMonthProvider.notifier).state = shiftMonth(month, -1),
            onNext: () =>
                ref.read(budgetsMonthProvider.notifier).state = shiftMonth(month, 1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(budgetSummaryProvider),
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.green,
          onRefresh: () => ref.refresh(budgetSummaryProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _OverallCard(line: data.overall, month: month),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('By category'),
                      const SizedBox(height: 16),
                      if (data.categories.isEmpty)
                        Text(
                          'Nothing spent this month yet.',
                          style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                        ),
                      for (final line in data.categories) ...[
                        _CategoryRow(line: line, month: month),
                        if (line != data.categories.last)
                          Divider(
                            height: 24,
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallCard extends ConsumerWidget {
  const _OverallCard({required this.line, required this.month});

  final BudgetLine line;
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppTheme.green,
      child: InkWell(
        onTap: () => showBudgetSheet(context, ref, month: month, line: line, overall: true),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Eyebrow('Overall budget', onBrand: true)),
                  Icon(Icons.edit_outlined,
                      size: 18, color: Colors.white.withValues(alpha: 0.8)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                line.budget == null
                    ? money(line.spent)
                    : '${money(line.spent)} / ${money(line.budget!)}',
                style: textTheme.headlineSmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (line.budget != null) ...[
                ProgressTrack(percent: line.barPercent, status: line.status, onBrand: true),
                const SizedBox(height: 8),
                Text(
                  line.status == 'over'
                      ? 'Over by ${money((line.remaining ?? '0').replaceFirst('-', ''))}'
                      : '${money(line.remaining ?? '0.00')} left',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ] else
                Text(
                  'Tap to set a budget for ${monthLabel(month)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.line, required this.month});

  final BudgetLine line;
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = CategoryStyle.color(line.color);

    return InkWell(
      onTap: () => showBudgetSheet(context, ref, month: month, line: line),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CategoryStyle.icon(line.icon), size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(line.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                line.budget == null
                    ? money(line.spent)
                    : '${money(line.spent)} / ${money(line.budget!)}',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ),
          if (line.budget != null) ...[
            const SizedBox(height: 8),
            ProgressTrack(percent: line.barPercent, status: line.status),
          ],
        ],
      ),
    );
  }
}

/// Set / change / remove one budget slot. The POST is an upsert, so the sheet
/// never needs to know whether the slot already exists — except for Remove,
/// which needs the row's uuid from GET /budgets.
Future<void> showBudgetSheet(
  BuildContext context,
  WidgetRef ref, {
  required String month,
  required BudgetLine line,
  bool overall = false,
}) {
  final controller = TextEditingController(text: line.budget ?? '');

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                overall
                    ? 'Overall budget — ${monthLabel(month)}'
                    : '${line.name} — ${monthLabel(month)}',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Amount', prefixText: '\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final amount = controller.text.trim();
                  if (double.tryParse(amount) == null) return;

                  try {
                    await ref.read(repositoryProvider).setBudget(
                          month: month,
                          amount: amount,
                          categoryUuid: overall ? null : line.uuid,
                        );

                    ref
                      ..invalidate(budgetSummaryProvider)
                      ..invalidate(budgetRowsProvider)
                      ..invalidate(dashboardProvider);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  } catch (e) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext)
                          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                    }
                  }
                },
                child: const Text('Save budget'),
              ),
              if (line.budget != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    try {
                      // Summary rows carry no budget uuid; the stored rows do.
                      final rows = await ref.read(repositoryProvider).budgets(month);
                      final match = rows.where(
                        (b) => overall
                            ? b.category == null
                            : b.category?.uuid == line.uuid,
                      );

                      if (match.isNotEmpty) {
                        await ref.read(repositoryProvider).deleteBudget(match.first.uuid);
                        ref
                          ..invalidate(budgetSummaryProvider)
                          ..invalidate(budgetRowsProvider)
                          ..invalidate(dashboardProvider);
                      }

                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    } catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext)
                            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                      }
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  child: const Text('Remove budget'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
