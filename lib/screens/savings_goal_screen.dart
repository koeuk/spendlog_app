import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../models/savings.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'savings_entry_sheet.dart';
import 'savings_goal_sheet.dart';
import 'savings_screen.dart';

/// One goal: where it stands, and every deposit and withdrawal behind that.
class SavingsGoalScreen extends ConsumerWidget {
  const SavingsGoalScreen({super.key, required this.uuid});

  final String uuid;

  static const _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(savingsGoalProvider(uuid));
    final loaded = goal.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          loaded?.name ?? 'Goal',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (loaded != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit goal',
              onPressed: () => _edit(context, loaded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: loaded == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AddPill(
                  label: 'Withdraw',
                  icon: Icons.remove,
                  onPressed: () =>
                      showSavingsEntrySheet(context, goal: loaded, type: 'withdraw'),
                ),
                const SizedBox(width: 10),
                AddPill(
                  label: 'Deposit',
                  onPressed: () => showSavingsEntrySheet(context, goal: loaded),
                ),
              ],
            ),
      body: goal.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.accent(context))),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(savingsGoalProvider(uuid)),
        ),
        data: (data) {
          final entries = data.entries ?? const <SavingsEntry>[];

          return RefreshIndicator(
            color: AppTheme.accent(context),
            onRefresh: () => refreshQuietly(ref.refresh(savingsGoalProvider(uuid).future)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageInset,
                8,
                AppTheme.pageInset,
                AppTheme.navBarClearance + 72,
              ),
              children: [
                _ProgressCard(goal: data),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Eyebrow('History'),
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Nothing saved towards this yet.',
                        style: TextStyle(color: AppTheme.faint(context, 0.5)),
                      ),
                    ),
                  ),
                for (final entry in entries) ...[
                  _EntryTile(
                    entry: entry,
                    onDelete: () => _deleteEntry(context, ref, data, entry),
                  ),
                  if (entry != entries.last) const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, SavingsGoal goal) async {
    final deleted = await showSavingsGoalSheet(context, goal: goal);

    // The goal this screen shows is gone; there is nothing left to stand on.
    if (deleted == true && context.mounted) context.pop();
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
    SavingsEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(entry.isDeposit ? 'Delete this deposit?' : 'Delete this withdrawal?'),
        content: Text('${money(entry.amount)} on ${dayLabel(entry.savedOn)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteSavingsEntry(goal.uuid, entry.uuid);
      invalidateSavings(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

/// The headline card, painted in the goal's own colour so the screen reads
/// as belonging to that goal rather than to the app in general.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(goal.color);
    final textTheme = Theme.of(context).textTheme;
    final muted = Colors.white.withValues(alpha: 0.8);

    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('Saved so far', onBrand: true)),
                if (goal.reached) const ReachedBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  money(goal.saved),
                  style: textTheme.headlineMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'of ${money(goal.targetAmount)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressTrack(percent: goal.percent, onBrand: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.reached
                        ? '${goal.percent}% · goal reached'
                        : '${goal.percent}% · ${money(goal.remaining)} to go',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                if (goal.deadline != null)
                  Text(
                    'By ${dayLabel(goal.deadline!)}',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});

  final SavingsEntry entry;
  final VoidCallback onDelete;

  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final deposit = entry.isDeposit;
    final color = deposit ? AppTheme.accent(context) : _red;
    final subtitle = [
      if (entry.savedOn.isNotEmpty) dayLabel(entry.savedOn),
      if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
    ].join(' · ');

    return Card(
      shape: AppTheme.rowShape(context),
      child: InkWell(
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
                      deposit ? 'Deposit' : 'Withdrawal',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.45)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${deposit ? '+' : '−'}${money(entry.amount)}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
