import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/borrowing.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'borrowing_form_page.dart';
import 'borrowing_repayment_page.dart';
import 'borrowings_screen.dart';

/// One borrowing: what is still owed, the terms, and the ledger of
/// repayments that produced the figure. Every action on a debt starts here.
class BorrowingDetailScreen extends StatelessWidget {
  const BorrowingDetailScreen({super.key, required this.uuid});

  final String uuid;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    // Keyed by uuid: the notifier holds whichever borrowings were opened, so
    // a sheet's invalidate refreshes this page without knowing which it is.
    final detail = context.watch<BorrowingDetailNotifier>().state(uuid);
    final lender = detail.valueOrNull?.lender ?? tr('Borrowing');

    return Scaffold(
      appBar: AppBar(leading: glassBack(context), title: Text(lender)),
      body: detail.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () =>
              context.read<BorrowingDetailNotifier>().invalidate(uuid),
        ),
        data: (borrowing) => RefreshIndicator(
          color: AppTheme.accent(context),
          // `refresh` never throws — see FamilyAsyncNotifier.refresh.
          onRefresh: () =>
              context.read<BorrowingDetailNotifier>().refresh(uuid),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance + 24,
            ),
            children: [
              _TermsCard(
                borrowing: borrowing,
                onRepay: () =>
                    showBorrowingRepaymentSheet(context, borrowing: borrowing),
                onEdit: () => _edit(context, borrowing),
                onDelete: () => _delete(context, borrowing),
              ),
              const SizedBox(height: 12),
              _LedgerCard(
                borrowing: borrowing,
                onDeleteRepayment: (repayment) =>
                    _deleteRepayment(context, borrowing, repayment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Borrowing borrowing) async {
    final result = await showBorrowingForm(context, borrowing: borrowing);

    // The sheet offers Delete too; once the row is gone this page is about
    // nothing, so it leaves with it.
    if (result == BorrowingFormResult.deleted && context.mounted) {
      context.pop();
    }
  }

  Future<void> _delete(BuildContext context, Borrowing borrowing) async {
    final confirmed = await confirmDeleteBorrowing(context, borrowing);
    if (confirmed != true || !context.mounted) return;

    // Both captured before the delete: `context` must not be touched across
    // an await, and the refresh has to land after this page has gone.
    final repository = context.read<SpendLogRepository>();
    final refresh = borrowingsInvalidator(context);

    try {
      await repository.deleteBorrowing(borrowing.uuid);

      // Leave first, then invalidate: a rebuild of this page after the
      // invalidate would ask the server for a row that no longer exists.
      if (context.mounted) context.pop();
      refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _deleteRepayment(
    BuildContext context,
    Borrowing borrowing,
    BorrowingRepayment repayment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Delete this repayment?')),
        content: Text(
          '${money(repayment.amount)} · ${dayLabel(repayment.paidOn)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repository = context.read<SpendLogRepository>();

    try {
      await repository.deleteBorrowingRepayment(borrowing.uuid, repayment.uuid);
      // Removing a repayment reopens what it had paid off, so every figure
      // moves — the list, the summary, and this page.
      if (context.mounted) invalidateBorrowings(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// The headline and the terms: what is still owed (or, once settled, what
/// was borrowed), how far along the repayments are, the dates, the note —
/// and the three things that can be done about it.
class _TermsCard extends StatelessWidget {
  const _TermsCard({
    required this.borrowing,
    required this.onRepay,
    required this.onEdit,
    required this.onDelete,
  });

  final Borrowing borrowing;
  final VoidCallback onRepay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final faint = AppTheme.faint(context, 0.5);
    final settled = borrowing.settled;
    final dueOn = borrowing.dueOn;
    final note = borrowing.note;

    final dueColor = settled
        ? accent
        : borrowing.overdue
        ? _red
        : Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(
              '${tr(settled ? 'Paid back' : 'Still owed')} · '
              '${tr(lenderTypeLabel(borrowing.lenderType))}',
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(settled ? borrowing.amount : borrowing.remaining),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: settled ? accent : null,
                ),
              ),
            ),
            if (!settled) ...[
              const SizedBox(height: 8),
              Text(
                '${tr('Repaid')} ${money(borrowing.repaid)} ${tr('of')} ${money(borrowing.amount)}',
                style: TextStyle(color: faint, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              ProgressTrack(
                percent: borrowing.percentRepaid,
                color: borrowing.overdue ? _red : accent,
              ),
            ],
            const SizedBox(height: 16),
            _Term(
              label: tr('Borrowed on'),
              value: dayLabel(borrowing.borrowedOn),
            ),
            const SizedBox(height: 8),
            _Term(
              label: tr('Due on'),
              value: dueOn == null
                  ? tr('No due date')
                  : borrowing.overdue
                  ? '${tr('Overdue since')} ${dayLabel(dueOn)}'
                  : dayLabel(dueOn),
              color: dueOn == null ? faint : dueColor,
            ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Term(label: tr('Note'), value: note),
            ],
            const SizedBox(height: 18),
            // Repaying is what an open debt is for, so it leads.
            if (!settled) ...[
              FilledButton.icon(
                onPressed: onRepay,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(tr('Record repayment')),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(tr('Edit')),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      shape: const StadiumBorder(),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(color: AppTheme.faint(context, 0.12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(tr('Delete')),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: _red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One line of the terms: a faint label, the value beside it.
class _Term extends StatelessWidget {
  const _Term({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppTheme.faint(context, 0.5)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// The ledger: every repayment, newest first. Each line can be deleted —
/// there is no edit, since a wrong repayment is simply removed and
/// recorded again.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.borrowing, required this.onDeleteRepayment});

  final Borrowing borrowing;
  final ValueChanged<BorrowingRepayment> onDeleteRepayment;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final faint = AppTheme.faint(context, 0.45);
    final repayments = borrowing.repayments;
    final hairline = AppTheme.faint(context, 0.06);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Expanded(child: Eyebrow(tr('Repayments'))),
                  if (repayments.isNotEmpty)
                    Text(
                      money(borrowing.repaid),
                      style: TextStyle(fontSize: 12, color: faint),
                    ),
                ],
              ),
            ),
            if (repayments.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 12, 10),
                child: Text(
                  tr('No repayments yet.'),
                  style: TextStyle(color: AppTheme.faint(context, 0.5)),
                ),
              )
            else
              for (final repayment in repayments) ...[
                if (repayment != repayments.first)
                  Divider(height: 1, thickness: 1, color: hairline),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '−${money(repayment.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (repayment.paidOn.isNotEmpty)
                                  dayLabel(repayment.paidOn),
                                if (repayment.note != null &&
                                    repayment.note!.isNotEmpty)
                                  repayment.note!,
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: faint),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDeleteRepayment(repayment),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppTheme.faint(context, 0.4),
                      tooltip: tr('Delete'),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}
