import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
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
import 'savings_goal_sheet.dart';

/// Every savings goal, with the totals across them up top.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(savingsMonthProvider);
    final summary = ref.watch(savingsSummaryProvider);
    final goals = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Savings')),
      ),
      floatingActionButton: AddPill(
        label: tr('New goal'),
        onPressed: () => showSavingsGoalSheet(context),
      ),
      body: summary.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.accent(context))),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () {
            ref.invalidate(savingsSummaryProvider);
            ref.invalidate(savingsGoalsProvider);
          },
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          onRefresh: () {
            ref.invalidate(savingsGoalsProvider);

            return refreshQuietly(ref.refresh(savingsSummaryProvider.future));
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
              // Only the "saved this month" line is month-bound; the goals
              // and their totals are all-time. The stepper is for that line.
              Align(
                alignment: Alignment.centerRight,
                child: MonthStepper(
                  month: month,
                  onChanged: (ym) => ref.read(savingsMonthProvider.notifier).state = ym,
                ),
              ),
              const SizedBox(height: 4),
              _SummaryCard(summary: data, month: month),
              const SizedBox(height: 16),
              ..._goalCards(context, ref, goals),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _goalCards(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SavingsGoal>> goals,
  ) {
    return goals.when(
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
          onRetry: () => ref.invalidate(savingsGoalsProvider),
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
                    Icons.savings_outlined,
                    size: 44,
                    color: AppTheme.faint(context, 0.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('No goals yet — start one.'),
                    style: TextStyle(color: AppTheme.faint(context, 0.5)),
                  ),
                ],
              ),
            ),
          ];
        }

        return [
          for (final goal in list) ...[
            GoalCard(
              goal: goal,
              onTap: () => context.go('/savings/${goal.uuid}'),
            ),
            if (goal != list.last) const SizedBox(height: 12),
          ],
        ];
      },
    );
  }
}

/// The totals across every goal, in the same green as the other headline
/// cards, with the one month-bound line beneath the bar.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.month});

  final SavingsSummary summary;
  final String month;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Colors.white.withValues(alpha: 0.8);

    return Card(
      color: AppTheme.accent(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(tr('Total saved'), onBrand: true),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  money(summary.totalSaved),
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'of ${money(summary.totalTarget)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressTrack(percent: summary.percent, onBrand: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${summary.percent}% · ${summary.goalsCount == 1 ? '1 goal' : '${summary.goalsCount} goals'}',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
                Text(
                  '${moneySigned(summary.savedThisMonth)} in ${monthLabel(month)}',
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

/// One goal in the list: name, its own coloured bar, and where it stands.
/// Public so the detail screen can head with the same card, bigger.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, this.onTap});

  final SavingsGoal goal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(goal.color);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (goal.reached) ...[
                    const SizedBox(width: 8),
                    const ReachedBadge(),
                  ] else
                    Text(
                      '${goal.percent}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.faint(context, 0.55),
                      ),
                    ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppTheme.faint(context, 0.25),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ProgressTrack(percent: goal.percent, color: color),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${money(goal.saved)} of ${money(goal.targetAmount)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.faint(context, 0.55),
                      ),
                    ),
                  ),
                  if (goal.deadline != null)
                    Text(
                      'By ${dayLabel(goal.deadline!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.faint(context, 0.45),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small green pill a goal wears once its saved total meets the target.
class ReachedBadge extends StatelessWidget {
  const ReachedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent(context).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 13, color: AppTheme.accent(context)),
          SizedBox(width: 3),
          Text(
            tr('Reached'),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent(context),
            ),
          ),
        ],
      ),
    );
  }
}
