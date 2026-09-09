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
      appBar: AppBar(
        // A tab-like root: the title starts the line and the stepper takes the
        // actions slot, exactly as Budgets does.
        centerTitle: false,
        title: Text(tr('Savings')),
        actions: [
          MonthStepper(
            month: month,
            onChanged: (ym) => ref.read(savingsMonthProvider.notifier).state = ym,
          ),
          const SizedBox(width: 8),
        ],
      ),
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
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            children: [
              _PlanCard(summary: data, month: month),
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

/// The one headline card: the all-time balance up top, then the month against
/// its plan. Tapping it — or its pencil — sets the plan, the way the Budgets
/// overall card does.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.summary, required this.month});

  final SavingsSummary summary;
  final String month;

  /// The status read on a green card: pale green once met, pale amber while
  /// close, plain white otherwise. `CategoryStyle.statusColor` is the budget
  /// scale, where the colours mean the opposite thing.
  static Color _statusInk(String status) => switch (status) {
        'met' => const Color(0xFFDCFCE7),
        'close' => const Color(0xFFFEF9C3),
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Colors.white.withValues(alpha: 0.8);

    return Card(
      color: AppTheme.accent(context),
      child: InkWell(
        onTap: () => showSavingsPlanSheet(
          context,
          month: month,
          planned: summary.planned,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Eyebrow(tr('Total saved'), onBrand: true)),
                  Icon(Icons.edit_outlined, size: 18, color: muted),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                money(summary.totalSaved),
                style: textTheme.headlineMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              if (summary.hasPlan) ...[
                ProgressTrack(
                  percent: summary.percent,
                  status: summary.status,
                  onBrand: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${summary.percent}%',
                      style: TextStyle(
                        color: _statusInk(summary.status),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${moneySigned(summary.savedThisMonth)} of ${money(summary.planned)} ${tr('this month')}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ] else
                Text(
                  '${tr('No savings planned for')} ${monthLabel(month)}',
                  style: TextStyle(color: muted, fontSize: 13),
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
