import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/income.dart';
import '../repositories/spendlog_repository.dart';
import '../providers/async_notifier.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'income_form_sheet.dart';

/// One month of income: the total up top, every entry beneath it.
class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final month = context.watch<IncomeMonth>().value;
    final summary = context.watch<IncomeSummaryNotifier>().state;
    final incomes = context.watch<IncomesNotifier>().state;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Income'))),
      floatingActionButton: AddPill(
        label: tr('Add'),
        onPressed: () => showIncomeForm(context),
      ),
      body: summary.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () {
            context.read<IncomeSummaryNotifier>().invalidate();
            context.read<IncomesNotifier>().invalidate();
          },
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          onRefresh: () {
            context.read<IncomesNotifier>().invalidate();

            // `refresh` never throws — see AsyncNotifier.refresh.
            return context.read<IncomeSummaryNotifier>().refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              0,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            children: [
              // The month being viewed sits with the card it governs rather
              // than in the app bar, where it squeezed the title.
              Align(
                alignment: Alignment.centerRight,
                child: MonthStepper(
                  month: month,
                  onChanged: (ym) => context.read<IncomeMonth>().value = ym,
                ),
              ),
              const SizedBox(height: 4),
              _SummaryCard(summary: data, month: month),
              const SizedBox(height: 16),
              ..._rows(context, incomes),
            ],
          ),
        ),
      ),
    );
  }

  /// The month's entries live on their own notifier so a slow list never
  /// holds the summary card hostage — and vice versa.
  List<Widget> _rows(BuildContext context, AsyncState<List<Income>> incomes) {
    return incomes.when(
      loading: () => [
        Padding(
          padding: EdgeInsets.only(top: 32),
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
        ),
      ],
      error: (e, _) => [
        LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => context.read<IncomesNotifier>().invalidate(),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 44,
                    color: AppTheme.faint(context, 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('No income recorded this month.'),
                    style: TextStyle(color: AppTheme.faint(context, 0.5)),
                  ),
                ],
              ),
            ),
          ];
        }

        return [
          for (final income in list) ...[
            _IncomeTile(
              income: income,
              onTap: () => showIncomeForm(context, income: income),
              onDelete: () => _delete(context, income),
            ),
            if (income != list.last) const SizedBox(height: 10),
          ],
        ];
      },
    );
  }

  Future<void> _delete(BuildContext context, Income income) async {
    final confirmed = await confirmDeleteIncome(context, income);
    if (confirmed != true || !context.mounted) return;

    // Read before the delete: `context` must not be touched across an await.
    final repository = context.read<SpendLogRepository>();

    try {
      await repository.deleteIncome(income.uuid);
      if (context.mounted) invalidateIncome(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// The month's headline: total, how many entries, and where most of it came
/// from. Solid green like the dashboard's month card — it is the same kind of
/// figure, just the other side of the ledger.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.month});

  final IncomeSummary summary;
  final String month;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Colors.white.withValues(alpha: 0.8);
    final top = summary.bySource.take(3).toList();

    return Card(
      color: AppTheme.accent(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow('Income · ${monthLabel(month)}', onBrand: true),
            const SizedBox(height: 8),
            Text(
              money(summary.total),
              style: textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary.count == 1 ? '1 entry' : '${summary.count} entries',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              for (final line in top) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.source,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Text(
                      money(line.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                if (line != top.last) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _IncomeTile extends StatelessWidget {
  const _IncomeTile({
    required this.income,
    required this.onTap,
    required this.onDelete,
  });

  final Income income;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (income.receivedOn.isNotEmpty) dayLabel(income.receivedOn),
      if (income.note != null && income.note!.isNotEmpty) income.note!,
    ].join(' · ');

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
                  color: AppTheme.accent(context).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 20,
                  color: AppTheme.accent(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income.source,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty || income.recurring) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.faint(context, 0.45),
                              ),
                            ),
                          ),
                          // Made by a recurring rule, not typed in.
                          if (income.recurring) ...[
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
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '+${money(income.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.accent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
