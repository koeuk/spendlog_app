import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/borrowing.dart';
import '../providers/async_notifier.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'borrowing_form_sheet.dart';

/// Money owed to a friend, family or a bank: what is still outstanding up
/// top, every debt beneath it. All time, not a month — a debt does not
/// belong to one, so there is no stepper here.
class BorrowingsScreen extends StatelessWidget {
  const BorrowingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<BorrowingStatus>().value;
    final summary = context.watch<BorrowingSummaryNotifier>().state;
    final rows = context.watch<BorrowingsNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        leading: glassBack(context),
        centerTitle: false,
        title: Text(tr('Borrowing')),
      ),
      floatingActionButton: AddPill(
        label: tr('Add'),
        onPressed: () => showBorrowingForm(context),
      ),
      body: summary.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () {
            context.read<BorrowingSummaryNotifier>().invalidate();
            context.read<BorrowingsNotifier>().invalidate();
          },
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          onRefresh: () {
            context.read<BorrowingsNotifier>().invalidate();

            // `refresh` never throws — see AsyncNotifier.refresh.
            return context.read<BorrowingSummaryNotifier>().refresh();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 72,
            ),
            children: [
              _SummaryRow(summary: data),
              if (data.byLenderType.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ByLenderTypeCard(lines: data.byLenderType),
              ],
              const SizedBox(height: 20),
              // Still owed leads: what you owe is what you came to see, and
              // a settled debt is a record rather than a task.
              Row(
                children: [
                  for (final option in const ['open', 'settled', 'all']) ...[
                    Expanded(
                      child: PillSegment(
                        label: tr(_statusLabel(option)),
                        selected: status == option,
                        onTap: () =>
                            context.read<BorrowingStatus>().value = option,
                      ),
                    ),
                    if (option != 'all') const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              ..._rows(context, status, rows),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'open' => 'Still owed',
    'settled' => 'Paid back',
    _ => 'All',
  };

  /// The rows live on their own notifier so a slow list never holds the
  /// summary cards hostage — and vice versa.
  List<Widget> _rows(
    BuildContext context,
    String status,
    AsyncState<List<Borrowing>> rows,
  ) {
    return rows.when(
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
          onRetry: () => context.read<BorrowingsNotifier>().invalidate(),
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
                    Icons.handshake_outlined,
                    size: 44,
                    color: AppTheme.faint(context, 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(switch (status) {
                      'open' => 'Nothing still owed.',
                      'settled' => 'Nothing paid back yet.',
                      _ => 'No borrowing yet, add your first one.',
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.faint(context, 0.5)),
                  ),
                ],
              ),
            ),
          ];
        }

        return [
          for (final borrowing in list) ...[
            BorrowingRow(
              borrowing: borrowing,
              onTap: () => context.push('/borrowings/${borrowing.uuid}'),
              onLongPress: () => _delete(context, borrowing),
            ),
            if (borrowing != list.last) const SizedBox(height: 10),
          ],
        ];
      },
    );
  }

  Future<void> _delete(BuildContext context, Borrowing borrowing) async {
    final confirmed = await confirmDeleteBorrowing(context, borrowing);
    if (confirmed != true || !context.mounted) return;

    // Read before the delete: `context` must not be touched across an await.
    final repository = context.read<SpendLogRepository>();

    try {
      await repository.deleteBorrowing(borrowing.uuid);
      if (context.mounted) invalidateBorrowings(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// The two figures side by side: what is still owed right now, and how much
/// was ever borrowed against how much has come back. Two cards because they
/// answer different questions — the first is a task, the second a record.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final BorrowingSummary summary;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _OutstandingCard(summary: summary)),
          const SizedBox(width: 12),
          Expanded(child: _BorrowedCard(summary: summary)),
        ],
      ),
    );
  }
}

/// Everything still owed, across every open debt. Red rather than the accent
/// when any of it is overdue — the one figure here that wants attention.
class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.summary});

  final BorrowingSummary summary;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.8);
    final overdue = summary.overdueCount > 0;

    return Card(
      color: overdue ? _red : AppTheme.accent(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Eyebrow(tr('Still owed'), onBrand: true),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(summary.outstanding),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                '${summary.openCount} ${tr('open')}',
                if (overdue) '${summary.overdueCount} ${tr('overdue')}',
              ].join(' · '),
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// The record: what was ever borrowed and what has come back.
class _BorrowedCard extends StatelessWidget {
  const _BorrowedCard({required this.summary});

  final BorrowingSummary summary;

  @override
  Widget build(BuildContext context) {
    final faint = AppTheme.faint(context, 0.5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Eyebrow(tr('Borrowed in total')),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(summary.borrowed),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${tr('Repaid so far')}: ${money(summary.repaid)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: faint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is still owed to each kind of lender, largest first. Only shown
/// when something is outstanding, since it lists nothing otherwise.
class _ByLenderTypeCard extends StatelessWidget {
  const _ByLenderTypeCard({required this.lines});

  final List<LenderTypeOutstanding> lines;

  @override
  Widget build(BuildContext context) {
    final faint = AppTheme.faint(context, 0.5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Still owed by lender type')),
            const SizedBox(height: 10),
            for (final line in lines) ...[
              Row(
                children: [
                  Icon(lenderTypeIcon(line.lenderType), size: 18, color: faint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      // The server's label follows the app locale, so it is
                      // preferred; the English fallback is for an older build.
                      line.label.isNotEmpty
                          ? line.label
                          : tr(lenderTypeLabel(line.lenderType)),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  Text(
                    '${line.count}',
                    style: TextStyle(color: faint, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    money(line.outstanding),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              if (line != lines.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// One debt: who, what kind, when it is due, and what is still owed.
class BorrowingRow extends StatelessWidget {
  const BorrowingRow({
    super.key,
    required this.borrowing,
    required this.onTap,
    this.onLongPress,
  });

  final Borrowing borrowing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final dueOn = borrowing.dueOn;
    final iconColor = borrowing.overdue
        ? _red
        : borrowing.settled
        ? AppTheme.faint(context, 0.45)
        : accent;

    final detail = [
      tr(lenderTypeLabel(borrowing.lenderType)),
      if (borrowing.borrowedOn.isNotEmpty) dayLabel(borrowing.borrowedOn),
    ].join(' · ');

    return Card(
      shape: AppTheme.rowShape(context),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      lenderTypeIcon(borrowing.lenderType),
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          borrowing.lender,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.faint(context, 0.45),
                          ),
                        ),
                        // The due date only matters while something is owed.
                        if (!borrowing.settled && dueOn != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            borrowing.overdue
                                ? '${tr('Overdue since')} ${dayLabel(dueOn)}'
                                : '${tr('Due')} ${dayLabel(dueOn)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: borrowing.overdue
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: borrowing.overdue
                                  ? _red
                                  : AppTheme.faint(context, 0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(
                          borrowing.settled
                              ? borrowing.amount
                              : borrowing.remaining,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: borrowing.settled
                              ? accent
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        borrowing.settled
                            ? tr('Paid back')
                            : '${tr('of')} ${money(borrowing.amount)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: borrowing.settled
                              ? accent
                              : AppTheme.faint(context, 0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Progress only once something has come back: a full-width
              // empty bar under every new debt is noise.
              if (!borrowing.settled && borrowing.percentRepaid > 0) ...[
                const SizedBox(height: 12),
                ProgressTrack(
                  percent: borrowing.percentRepaid,
                  color: borrowing.overdue ? _red : accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one confirm dialog the list's long-press, the detail page and the
/// edit sheet all use, so the three cannot word it differently.
Future<bool?> confirmDeleteBorrowing(
  BuildContext context,
  Borrowing borrowing,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Delete this borrowing?')),
      content: Text(
        '${borrowing.lender} — ${money(borrowing.amount)}\n'
        '${tr('Every repayment against it will be removed too.')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          child: Text(tr('Delete')),
        ),
      ],
    ),
  );
}

/// An icon per kind of lender, so a row reads at a glance.
IconData lenderTypeIcon(String type) => switch (type) {
  'friend' => Icons.person_outline,
  'family' => Icons.family_restroom_outlined,
  'bank' => Icons.account_balance_outlined,
  'employer' => Icons.work_outline,
  _ => Icons.handshake_outlined,
};
