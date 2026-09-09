import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/recurring.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Create or edit one recurring rule in a bottom sheet. Saving runs the rule
/// server-side at once, so every money figure is invalidated on the way out —
/// a rule starting today has already put a row on the books.
Future<void> showRecurringForm(
  BuildContext context, {
  RecurringRule? rule,
  String kind = 'expense',
}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _RecurringForm(rule: rule, initialKind: kind),
    ),
  );
}

class _RecurringForm extends ConsumerStatefulWidget {
  const _RecurringForm({this.rule, required this.initialKind});

  final RecurringRule? rule;
  final String initialKind;

  @override
  ConsumerState<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<_RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.rule?.title ?? '');
  late final _amount = TextEditingController(text: widget.rule?.amount ?? '');
  late final _note = TextEditingController(text: widget.rule?.note ?? '');

  late String _kind = widget.rule?.kind ?? widget.initialKind;
  late String? _categoryUuid = widget.rule?.category?.uuid;
  late String _frequency = widget.rule?.frequency ?? 'monthly';
  late DateTime _startsOn = widget.rule != null && widget.rule!.startsOn.isNotEmpty
      ? DateTime.parse(widget.rule!.startsOn)
      : DateTime.now();
  late DateTime? _endsOn = widget.rule?.endsOn != null && widget.rule!.endsOn!.isNotEmpty
      ? DateTime.parse(widget.rule!.endsOn!)
      : null;
  late bool _active = widget.rule?.active ?? true;

  /// What the *entered* amount is denominated in; storage is always USD,
  /// converted server-side.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  bool get _editing => widget.rule != null;
  bool get _isExpense => _kind == 'expense';

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final today = DateTime.now();
    // On create the server catches up missed occurrences, but no further back
    // than a year; on edit the picker has to be able to land on the stored
    // date, however old.
    final first = _editing
        ? DateTime(2020)
        : DateTime(today.year - 1, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn.isBefore(first) ? first : _startsOn,
      firstDate: first,
      lastDate: DateTime(today.year + 10),
    );

    if (picked != null) {
      setState(() {
        _startsOn = picked;
        // An end before the start is a guaranteed 422; drop it rather than
        // send it.
        if (_endsOn != null && !_endsOn!.isAfter(picked)) _endsOn = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final first = _startsOn.add(const Duration(days: 1));
    final initial = _endsOn ?? first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(DateTime.now().year + 30),
    );

    if (picked != null) setState(() => _endsOn = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(repositoryProvider);

    try {
      if (_editing) {
        await repo.updateRecurringRule(
          widget.rule!.uuid,
          kind: _kind,
          title: _title.text.trim(),
          amount: _amount.text.trim(),
          frequency: _frequency,
          startsOn: dateParam(_startsOn),
          categoryUuid: _isExpense ? _categoryUuid : null,
          endsOn: _endsOn == null ? null : dateParam(_endsOn!),
          note: _note.text,
          active: _active,
          currency: _currency,
        );
      } else {
        await repo.createRecurringRule(
          kind: _kind,
          title: _title.text.trim(),
          amount: _amount.text.trim(),
          frequency: _frequency,
          startsOn: dateParam(_startsOn),
          categoryUuid: _isExpense ? _categoryUuid : null,
          endsOn: _endsOn == null ? null : dateParam(_endsOn!),
          note: _note.text,
          currency: _currency,
        );
      }

      if (mounted) {
        invalidateRecurring(ref);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the rule.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deleting from the sheet, alongside the list's long-press — nothing on the
  /// row advertises the long-press, so the edit form offers the same in the open.
  Future<void> _delete() async {
    final confirmed = await confirmDeleteRecurring(context, widget.rule!);
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).deleteRecurringRule(widget.rule!.uuid);

      invalidateRecurring(ref);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the rule.');
        });
      }
    }
  }

  String _dayText(DateTime d) => '${d.day}/${d.month}/${d.year}';


  /// Rewrite the typed amount for the new currency rather than dropping it.
  /// Falls back to clearing only when the rate has not arrived, which is the
  /// one case where keeping the number would be a lie about how much money it
  /// is.
  void _switchCurrency(String next) {
    final rate = ref.read(moneySettingsProvider).valueOrNull?.khrPerUsd;
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
    final categories = ref.watch(categoriesProvider);
    final outline = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: const StadiumBorder(),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      side: BorderSide(color: AppTheme.faint(context, 0.12)),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? tr('Edit rule') : tr('New recurring rule'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorFill(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.errorInk(context), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // The kind is fixed once the rule exists — the server refuses to
              // change it, and the rows it made already belong to one ledger.
              Row(
                children: [
                  Expanded(
                    child: PillSegment(
                      label: tr('Expense'),
                      selected: _isExpense,
                      onTap: _editing ? () {} : () => setState(() => _kind = 'expense'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillSegment(
                      label: tr('Income'),
                      selected: !_isExpense,
                      onTap: _editing ? () {} : () => setState(() => _kind = 'income'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  hintText: _isExpense ? tr('What is it?') : tr('Source — salary, rent…'),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_editing,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give the rule a title.' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      decoration: InputDecoration(
                        hintText: tr('Amount'),
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed <= 0) return 'Enter an amount.';
                        if (_currency == 'KHR' && parsed < 100) return 'At least ៛100.';

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
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
              if (_currency == 'KHR') ...[
                const SizedBox(height: 8),
                Text(
                  tr('Entered in riel, stored in US dollars.'),
                  style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.5)),
                ),
              ],
              if (_isExpense) ...[
                const SizedBox(height: 14),
                categories.when(
                  loading: () => Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.accent(context)),
                      ),
                    ),
                  ),
                  error: (e, _) => Text(apiErrorMessage(e)),
                  data: (list) => DropdownButtonFormField<String>(
                    initialValue: _categoryUuid,
                    decoration: InputDecoration(hintText: tr('Category')),
                    items: [
                      for (final category in list)
                        DropdownMenuItem(
                          value: category.uuid,
                          child: Row(
                            children: [
                              Icon(
                                CategoryStyle.icon(category.icon),
                                size: 18,
                                color: CategoryStyle.color(category.color),
                              ),
                              const SizedBox(width: 10),
                              Text(category.name),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _categoryUuid = value),
                    validator: (v) =>
                        _isExpense && v == null ? 'Pick a category.' : null,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Eyebrow(tr('Repeats')),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final f in recurringFrequencies) ...[
                    Expanded(
                      child: PillSegment(
                        label: tr(frequencyLabel(f)),
                        selected: _frequency == f,
                        onTap: () => setState(() => _frequency = f),
                        height: 36,
                      ),
                    ),
                    if (f != recurringFrequencies.last) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickStart,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${tr('From')} ${_dayText(_startsOn)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                style: outline,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _endsOn == null
                            ? tr('No end date')
                            : '${tr('Until')} ${_dayText(_endsOn!)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      style: outline,
                    ),
                  ),
                  if (_endsOn != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _endsOn = null),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: tr('Clear end date'),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        shape: const CircleBorder(),
                        side: BorderSide(color: AppTheme.faint(context, 0.12)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                decoration: InputDecoration(hintText: tr('Note (optional)')),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 500,
                // The counter would sit oddly under a pill field; the limit
                // still applies.
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
              ),
              if (_editing) ...[
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  value: _active,
                  onChanged: (on) => setState(() => _active = on),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.accent(context),
                  title: Text(
                    tr('Active'),
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    tr('Paused rules create nothing until switched back on.'),
                    style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.5)),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing ? tr('Save changes') : tr('Create rule')),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  child: Text(tr('Delete rule')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one confirm dialog both the list's long-press and the sheet's delete
/// button use, so the two cannot word it differently.
Future<bool?> confirmDeleteRecurring(BuildContext context, RecurringRule rule) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Delete this rule?')),
      content: Text(
        '${rule.title} — ${money(rule.amount)} ${tr(frequencyLabel(rule.frequency)).toLowerCase()}. '
        '${tr('Rows it already created stay.')}',
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
