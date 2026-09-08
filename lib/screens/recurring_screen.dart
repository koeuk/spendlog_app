import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/recurring.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'recurring_form_sheet.dart';

/// Every recurring rule — the templates the server turns into expense and
/// income rows on schedule. Filtered by kind on-screen; the list is one call.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  /// null = all, otherwise expense | income.
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(recurringRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Recurring')),
      ),
      floatingActionButton: AddPill(
        label: tr('New rule'),
        onPressed: () => showRecurringForm(context, kind: _kind ?? 'expense'),
      ),
      body: rules.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.accent(context))),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(recurringRulesProvider),
        ),
        data: (all) {
          final list = _kind == null ? all : all.where((r) => r.kind == _kind).toList();

          return RefreshIndicator(
            color: AppTheme.accent(context),
            onRefresh: () => refreshQuietly(ref.refresh(recurringRulesProvider.future)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pageInset,
                4,
                AppTheme.pageInset,
                AppTheme.navBarClearance + 72,
              ),
              children: [
                Row(
                  children: [
                    for (final segment in const [
                      (kind: null, label: 'All'),
                      (kind: 'expense', label: 'Expenses'),
                      (kind: 'income', label: 'Income'),
                    ]) ...[
                      Expanded(
                        child: PillSegment(
                          label: tr(segment.label),
                          selected: _kind == segment.kind,
                          onTap: () => setState(() => _kind = segment.kind),
                        ),
                      ),
                      if (segment.kind != 'income') const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 44,
                          color: AppTheme.faint(context, 0.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          all.isEmpty
                              ? tr('No recurring rules yet — add rent, salary, subscriptions.')
                              : tr('Nothing of this kind repeats yet.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.faint(context, 0.5)),
                        ),
                      ],
                    ),
                  )
                else
                  for (final rule in list) ...[
                    _RuleTile(
                      rule: rule,
                      onTap: () => showRecurringForm(context, rule: rule),
                      onDelete: () => _delete(rule),
                    ),
                    if (rule != list.last) const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(RecurringRule rule) async {
    final confirmed = await confirmDeleteRecurring(context, rule);
    if (confirmed != true) return;

    try {
      await ref.read(repositoryProvider).deleteRecurringRule(rule.uuid);
      invalidateRecurring(ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onTap,
    required this.onDelete,
  });

  final RecurringRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = rule.isExpense
        ? CategoryStyle.color(rule.category?.color)
        : AppTheme.accent(context);
    final icon = rule.isExpense
        ? CategoryStyle.icon(rule.category?.icon)
        : Icons.payments_outlined;
    final ink = Theme.of(context).colorScheme.onSurface;

    // "Monthly · next 1 Oct" while the rule runs; once it stops there is no
    // next, so the chip says why instead.
    final subtitle = [
      tr(frequencyLabel(rule.frequency)),
      if (rule.active && rule.nextRunOn.isNotEmpty)
        '${tr('next')} ${dayLabel(rule.nextRunOn)}',
      if (rule.isExpense && rule.category != null) rule.category!.name,
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
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rule.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: rule.active ? ink : ink.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        if (!rule.active) ...[
                          const SizedBox(width: 8),
                          _StateChip(label: rule.ended ? tr('Ended') : tr('Paused')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
                rule.isExpense ? money(rule.amount) : '+${money(rule.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: rule.isExpense
                      ? (rule.active ? ink : ink.withValues(alpha: 0.55))
                      : AppTheme.accent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small grey pill a rule wears once it has stopped — paused by hand, or
/// ended because its last date has passed.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.faint(context, 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.faint(context, 0.55),
        ),
      ),
    );
  }
}
