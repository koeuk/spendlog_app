import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'activity_screen.dart';

/// The month card's screen: set the plan, or look back at what has been done
/// to the savings figures.
///
/// A screen rather than a sheet because the History tab is a list that wants
/// the whole height — a sheet had to cap it and scroll inside a scroll. Two
/// tabs rather than two routes: the card is one target, and "what is the plan"
/// and "who changed it" are the two questions it raises.
class SavingsPlanScreen extends StatefulWidget {
  const SavingsPlanScreen({super.key, required this.month, this.planned});

  final String month;

  /// The stored amount, prefilled. Null or "0.00" means no plan yet.
  final String? planned;

  @override
  State<SavingsPlanScreen> createState() => _SavingsPlanScreenState();
}

class _SavingsPlanScreenState extends State<SavingsPlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTab);

  /// Held here rather than in the form: the form leaves the tree while the
  /// History tab is showing, and a half-typed amount must survive a look at
  /// the log.
  late final TextEditingController _amount = TextEditingController(
    text: (double.tryParse(widget.planned ?? '') ?? 0) > 0
        ? widget.planned
        : '',
  );

  /// What the *entered* amount is denominated in. Storage is always USD,
  /// converted server-side — see App\Enums\Currency in the backend.
  String _currency = 'USD';

  /// Rewrite the typed amount for the new currency rather than dropping it.
  /// Falls back to clearing only when the rate has not arrived, which is the
  /// one case where keeping the number would be a lie about how much money it
  /// is.
  Future<void> _switchCurrency(String next) async {
    // Awaited, not read: the rate may not have been fetched yet, and a toggle
    // that blanks the amount because the answer had not arrived is worse than
    // one that takes a moment. See MoneySettingsNotifier.khrPerUsd.
    final rate = await context.read<MoneySettingsNotifier>().khrPerUsd();
    if (!mounted) return;

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

  void _onTab() {
    // The History tab has nothing to type into, and the keyboard would cover
    // half of it.
    if (_tabs.index == 1) FocusScope.of(context).unfocus();

    // The title follows the tab, and `index` moves before the animation
    // settles, so a rebuild on each notification is what keeps them together.
    setState(() {});
  }

  /// Back to the Savings screen. `pop` when there is something to pop —
  /// which is the only way in — and the route otherwise, so a deep link or a
  /// restored location still leaves somewhere to go.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/savings');
    }
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planning = _tabs.index == 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: IconButton(
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
          tooltip: tr('Back'),
        ),
        // Short on purpose: the month is a word too many beside a back button
        // at phone width, and the Plan tab names it in full anyway.
        title: Text(planning ? tr('Savings plan') : tr('Savings history')),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent(context),
          indicatorColor: AppTheme.accent(context),
          unselectedLabelColor: AppTheme.faint(context, 0.55),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: tr('Plan')),
            Tab(text: tr('History')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _PlanForm(
            month: widget.month,
            amount: _amount,
            currency: _currency,
            onCurrencyChanged: _switchCurrency,
          ),
          const _HistoryTab(),
        ],
      ),
    );
  }
}

/// The savings lines of the activity log, drawn with the Activity screen's own
/// tile so the two views cannot describe the same record differently.
class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SavingsHistoryNotifier>().state;

    return history.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: AppTheme.accent(context)),
      ),
      error: (e, _) => LoadFailed(
        message: apiErrorMessage(e),
        onRetry: () => context.read<SavingsHistoryNotifier>().invalidate(),
      ),
      data: (entries) => RefreshIndicator(
        color: AppTheme.accent(context),

        // `refresh` never throws — see AsyncNotifier.refresh.
        onRefresh: () => context.read<SavingsHistoryNotifier>().refresh(),
        child: entries.isEmpty
            // Still a scroll view, so pull-to-refresh works on the empty state
            // too — the one place a stale "nothing yet" is most likely.
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 72),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 44,
                          color: AppTheme.faint(context, 0.25),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr('Nothing has changed yet.'),
                          style: TextStyle(color: AppTheme.faint(context, 0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageInset,
                  14,
                  AppTheme.pageInset,
                  AppTheme.navBarClearance + 16,
                ),
                itemCount: entries.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => i == 0
                    // Said plainly, because the list is not filtered by the
                    // month the plan is for: the log records when a change was
                    // made, not which month it was about.
                    ? Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(
                          tr('Every change to your savings, newest first.'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.faint(context, 0.5),
                          ),
                        ),
                      )
                    : ActivityTile(entry: entries[i - 1]),
              ),
      ),
    );
  }
}

/// A widget rather than a bare builder so the form owns its validation, its
/// in-flight write and its own `BuildContext` — borrowing the card's would
/// outlive it whenever the screen rebuilt underneath. The typed amount and the
/// currency belong to the screen, which outlives a tab switch.
class _PlanForm extends StatefulWidget {
  const _PlanForm({
    required this.month,
    required this.amount,
    required this.currency,
    required this.onCurrencyChanged,
  });

  final String month;
  final TextEditingController amount;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Both captured before the write: `context` must not be touched across an
    // await, and the refresh must still land if this sheet is gone by then.
    final repository = context.read<SpendLogRepository>();
    final refresh = savingsInvalidator(context);

    try {
      await repository.setSavingsPlan(
        month: widget.month,
        amount: widget.amount.text.trim(),
        currency: widget.currency,
      );

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not save the plan.');
        });
      }
    }
  }

  Future<void> _clear(String uuid) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    // Captured before the write — see _save.
    final repository = context.read<SpendLogRepository>();
    final refresh = savingsInvalidator(context);

    try {
      await repository.deleteSavingsPlan(uuid);

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not clear the plan.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only the stored row carries a uuid, and only a stored row can be cleared.
    final plan = context
        .watch<SavingsPlanNotifier>()
        .state(widget.month)
        .valueOrNull;

    // Scrollable rather than a plain Column: the keyboard takes most of a
    // phone's height, and the Save button must stay reachable under it.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        18,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The month the plan is for, which the title has no room for.
            Text(
              monthLabel(widget.month),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              tr('How much do you mean to put aside this month?'),
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.faint(context, 0.5),
              ),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorFill(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.errorInk(context),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.amount,
                    decoration: InputDecoration(
                      hintText: tr('Amount'),
                      prefixText: widget.currency == 'USD' ? '\$ ' : '៛ ',
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
                      // amount that can be paid.
                      if (widget.currency == 'KHR' && parsed < 100) {
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
                  selected: {widget.currency},
                  onSelectionChanged: (selection) =>
                      widget.onCurrencyChanged(selection.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            if (widget.currency == 'KHR') ...[
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
                  : Text(tr('Save plan')),
            ),
            if (plan != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _clear(plan.uuid),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                child: Text(tr('Clear plan')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
