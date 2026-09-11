import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/budget_summary.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final month = context.watch<BudgetsMonth>().value;
    final summary = context.watch<BudgetSummaryNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        // A tab root with no back arrow: the title starts the line, the way
        // a list heading does. Pushed pages centre theirs between the arrow
        // and the actions.
        centerTitle: false,
        title: Text(tr('Budgets')),
        actions: [
          MonthStepper(
            month: month,
            onChanged: (ym) => context.read<BudgetsMonth>().value = ym,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: summary.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => context.read<BudgetSummaryNotifier>().invalidate(),
        ),
        data: (data) => RefreshIndicator(
          color: AppTheme.accent(context),
          // `refresh` never throws — see AsyncNotifier.refresh.
          onRefresh: () => context.read<BudgetSummaryNotifier>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              8,
              AppTheme.pageInset,
              AppTheme.navBarClearance,
            ),
            children: [
              _OverallCard(line: data.overall, month: month),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(tr('By category')),
                      const SizedBox(height: 16),
                      if (data.categories.isEmpty)
                        Text(
                          tr('Nothing spent this month yet.'),
                          style: TextStyle(color: AppTheme.faint(context, 0.5)),
                        ),
                      for (final line in data.categories) ...[
                        _CategoryRow(line: line, month: month),
                        if (line != data.categories.last)
                          Divider(
                            height: 24,
                            color: AppTheme.faint(context, 0.05),
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

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.line, required this.month});

  final BudgetLine line;
  final String month;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: AppTheme.accent(context),
      child: InkWell(
        onTap: () =>
            showBudgetSheet(context, month: month, line: line, overall: true),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Eyebrow(tr('Overall budget'), onBrand: true)),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                line.budget == null
                    ? money(line.spent)
                    : '${money(line.spent)} / ${money(line.budget!)}',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              if (line.budget != null) ...[
                ProgressTrack(
                  percent: line.barPercent,
                  status: line.status,
                  onBrand: true,
                ),
                const SizedBox(height: 8),
                Text(
                  line.status == 'over'
                      ? 'Over by ${moneyAbs(line.remaining ?? '0.00')}'
                      : '${money(line.remaining ?? '0.00')} left',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ] else
                Text(
                  'Tap to set a budget for ${monthLabel(month)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.line, required this.month});

  final BudgetLine line;
  final String month;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(line.color);

    return InkWell(
      onTap: () => showBudgetSheet(context, month: month, line: line),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CategoryStyle.icon(line.icon), size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.name ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                line.budget == null
                    ? money(line.spent)
                    : '${money(line.spent)} / ${money(line.budget!)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
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
  BuildContext context, {
  required String month,
  required BudgetLine line,
  bool overall = false,
}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BudgetForm(month: month, line: line, overall: overall),
    ),
  );
}

/// A widget rather than a bare builder so the sheet owns its controller, its
/// form state and — crucially — its own `BuildContext`. Borrowing the tapped
/// row's context would outlive that row whenever the list rebuilt underneath.
class _BudgetForm extends StatefulWidget {
  const _BudgetForm({
    required this.month,
    required this.line,
    required this.overall,
  });

  final String month;
  final BudgetLine line;
  final bool overall;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.line.budget ?? '');

  /// What the *entered* amount is denominated in. Storage is always USD,
  /// converted server-side — see App\Enums\Currency in the backend.
  String _currency = 'USD';

  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _report(Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    // Both captured before the write: `context` must not be touched across an
    // await, and the refresh must still land if this sheet is gone by then.
    final repository = context.read<SpendLogRepository>();
    final refreshMoneyOnScreen = moneyInvalidator(context);

    try {
      await repository.setBudget(
        month: widget.month,
        amount: _amount.text.trim(),
        categoryUuid: widget.overall ? null : widget.line.uuid,
        currency: _currency,
      );

      refreshMoneyOnScreen();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _report(e);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);

    // Captured before the write — see _save.
    final repository = context.read<SpendLogRepository>();
    final refreshMoneyOnScreen = moneyInvalidator(context);

    try {
      // Summary rows carry no budget uuid; the stored rows do.
      final rows = await repository.budgets(widget.month);
      final match = rows.where(
        (b) => widget.overall
            ? b.category == null
            : b.category?.uuid == widget.line.uuid,
      );

      if (match.isNotEmpty) {
        await repository.deleteBudget(match.first.uuid);
      }

      // Refresh either way: no matching row means the summary is showing a
      // budget the server no longer has, and closing on a stale figure would
      // look like the button did nothing.
      refreshMoneyOnScreen();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _report(e);
      }
    }
  }

  /// Rewrite the typed amount for the new currency rather than dropping it.
  /// Falls back to clearing only when the rate has not arrived, which is the
  /// one case where keeping the number would be a lie about how much money it
  /// is.
  void _switchCurrency(String next) {
    final rate = context
        .read<MoneySettingsNotifier>()
        .state
        .valueOrNull
        ?.khrPerUsd;
    final converted = rate == null
        ? null
        : convertAmount(
            _amount.text,
            from: _currency,
            to: next,
            khrPerUsd: rate,
          );

    setState(() {
      if (converted != null) {
        _amount.text = converted;
      } else if (rate == null) {
        _amount.clear();
      }
      _currency = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.overall
                    ? 'Overall budget — ${monthLabel(widget.month)}'
                    : '${widget.line.name} — ${monthLabel(widget.month)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      decoration: InputDecoration(
                        hintText: tr('Amount'),
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Enter an amount.';
                        }

                        // Mirrors Currency::minimumInput — ៛100 is the smallest
                        // note in circulation, so anything under it is not an
                        // amount that can be paid. The server rejects it too;
                        // this just says so before the round trip.
                        if (_currency == 'KHR' && parsed < 100) {
                          return 'At least ៛100.';
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'USD', label: Text('\$')),
                      ButtonSegment(value: 'KHR', label: Text('៛')),
                    ],
                    selected: {_currency},
                    onSelectionChanged: (selection) {
                      _switchCurrency(selection.first);
                    },
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (_currency == 'KHR') ...[
                const SizedBox(height: 8),
                Text(
                  tr('Entered in riel, stored in US dollars.'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.faint(context, 0.5),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(tr('Save budget')),
              ),
              if (widget.line.budget != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: Text(tr('Remove budget')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
