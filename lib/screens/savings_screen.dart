import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/savings.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'savings_entry_sheet.dart';
import 'savings_plan_sheet.dart';

/// The month's savings plan and what has actually gone aside against it —
/// budgets' twin on the other side of the ledger.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  static const _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(savingsMonthProvider);
    final summary = ref.watch(savingsSummaryProvider(month));
    final entries = ref.watch(savingsEntriesProvider(month));

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(tr('Savings'))),
      floatingActionButton: AddPill(
        label: tr('Add'),
        onPressed: () => showSavingsEntrySheet(context, month: month),
      ),
      body: summary.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppTheme.accent(context))),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () {
            ref.invalidate(savingsSummaryProvider(month));
            ref.invalidate(savingsEntriesProvider(month));
          },
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          onRefresh: () {
            ref.invalidate(savingsEntriesProvider(month));

            return refreshQuietly(ref.refresh(savingsSummaryProvider(month).future));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              0,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            children: [
              // The month sits with the card it governs rather than in the app
              // bar, where it crowded the title.
              Align(
                alignment: Alignment.centerRight,
                child: MonthStepper(
                  month: month,
                  onChanged: (ym) =>
                      ref.read(savingsMonthProvider.notifier).state = ym,
                ),
              ),
              const SizedBox(height: 4),
              _SummaryRow(summary: data, month: month),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Eyebrow(tr('This month')),
              ),
              const SizedBox(height: 10),
              ..._entryRows(context, ref, month, entries),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _entryRows(
    BuildContext context,
    WidgetRef ref,
    String month,
    AsyncValue<List<SavingsEntry>> entries,
  ) {
    return entries.when(
      loading: () => [
        Padding(
          padding: const EdgeInsets.only(top: 32),
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
          onRetry: () => ref.invalidate(savingsEntriesProvider(month)),
        ),
      ],
      data: (list) {
        if (list.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.savings_outlined,
                    size: 44,
                    color: AppTheme.faint(context, 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('Nothing put aside this month yet.'),
                    style: TextStyle(color: AppTheme.faint(context, 0.5)),
                  ),
                ],
              ),
            ),
          ];
        }

        return [
          for (final entry in list) ...[
            _EntryRow(
              entry: entry,
              onTap: () => showSavingsEntrySheet(context, entry: entry, month: month),
              onDelete: () => _deleteEntry(context, ref, entry),
            ),
            if (entry != list.last) const SizedBox(height: 10),
          ],
        ];
      },
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    SavingsEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(entry.isDeposit
            ? tr('Delete this deposit?')
            : tr('Delete this withdrawal?')),
        content: Text('${money(entry.amount)} · ${dayLabel(entry.savedOn)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteSavingsEntry(entry.uuid);
      invalidateSavings(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// The two figures side by side: everything put aside across every month,
/// and how this month is going against its plan. Two cards rather than one,
/// because they answer different questions — the running balance never
/// resets, the month always does.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary, required this.month});

  final SavingsSummary summary;
  final String month;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so the two stand equally tall when one carries a
    // progress bar and the other does not.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _TotalCard(summary: summary)),
          const SizedBox(width: 12),
          Expanded(child: _MonthCard(summary: summary, month: month)),
        ],
      ),
    );
  }
}

/// Every deposit less every withdrawal, all months. The running balance.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});

  final SavingsSummary summary;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.8);

    return Card(
      color: AppTheme.accent(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Eyebrow(tr('Total saved'), onBrand: true),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(summary.totalSaved),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr('All months'),
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// This month against its plan. The pencil sets the plan, since a plan is a
/// property of the month and nothing else on the screen owns it.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary, required this.month});

  final SavingsSummary summary;
  final String month;

  @override
  Widget build(BuildContext context) {
    final faint = AppTheme.faint(context, 0.5);

    return Card(
      child: InkWell(
        onTap: () => showSavingsPlanSheet(
          context,
          month: month,
          planned: summary.planned,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Expanded(child: Eyebrow(tr('This month'))),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppTheme.faint(context, 0.4),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  moneySigned(summary.savedThisMonth),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              if (summary.hasPlan) ...[
                ProgressTrack(
                  percent: summary.percent,
                  status: summary.status,
                ),
                const SizedBox(height: 6),
                Text(
                  '${summary.percent}% ${tr('of')} ${money(summary.planned)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: faint, fontSize: 12),
                ),
              ] else
                Text(
                  tr('No plan set'),
                  style: TextStyle(color: faint, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One deposit or withdrawal: green with a +, red with a −.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final SavingsEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final deposit = entry.isDeposit;
    final color = deposit ? AppTheme.accent(context) : _red;
    final note = entry.note;

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
                  deposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
                      deposit ? tr('Deposit') : tr('Withdrawal'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (entry.savedOn.isNotEmpty) dayLabel(entry.savedOn),
                        if (note != null && note.isNotEmpty) note,
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.faint(context, 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${deposit ? '+' : '−'}${money(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
