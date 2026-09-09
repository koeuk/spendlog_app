import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/income.dart';
import '../models/recurring.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Add / edit one income entry in a bottom sheet. On save the month's rows,
/// its summary and the dashboard (income and balance lines) are invalidated.
Future<void> showIncomeForm(BuildContext context, {Income? income}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _IncomeForm(income: income),
    ),
  );
}

class _IncomeForm extends ConsumerStatefulWidget {
  const _IncomeForm({this.income});

  final Income? income;

  @override
  ConsumerState<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends ConsumerState<_IncomeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _source = TextEditingController(text: widget.income?.source ?? '');
  late final _amount = TextEditingController(text: widget.income?.amount ?? '');
  late final _note = TextEditingController(text: widget.income?.note ?? '');

  late DateTime _receivedOn = widget.income != null && widget.income!.receivedOn.isNotEmpty
      ? DateTime.parse(widget.income!.receivedOn)
      : DateTime.now();

  /// What the *entered* amount is denominated in; storage is always USD,
  /// converted server-side.
  String _currency = 'USD';

  /// A frequency from [recurringFrequencies], or null for a one-off. Only
  /// offered on create: an existing row is a row, not a rule.
  String? _repeat;

  bool _busy = false;
  String? _error;

  bool get _editing => widget.income != null;

  @override
  void dispose() {
    _source.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receivedOn,
      firstDate: DateTime(2020),
      // The API refuses future income; don't offer what it will 422.
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => _receivedOn = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(repositoryProvider);
    final note = _note.text.trim();

    try {
      if (_editing) {
        await repo.updateIncome(
          widget.income!.uuid,
          source: _source.text.trim(),
          amount: _amount.text.trim(),
          receivedOn: dateParam(_receivedOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      } else if (_repeat != null) {
        // A rule instead of a row: the server runs it at once, so today's
        // income appears straight away and the rest follow on schedule.
        await repo.createRecurringRule(
          kind: 'income',
          title: _source.text.trim(),
          amount: _amount.text.trim(),
          frequency: _repeat!,
          startsOn: dateParam(_receivedOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      } else {
        await repo.createIncome(
          source: _source.text.trim(),
          amount: _amount.text.trim(),
          receivedOn: dateParam(_receivedOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      }

      if (mounted) {
        invalidateIncome(ref);
        if (_repeat != null) invalidateRecurring(ref);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the income.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deleting from the sheet, alongside the list's long-press — nothing on the
  /// row advertises the long-press, so the edit form offers the same in the open.
  Future<void> _delete() async {
    final confirmed = await confirmDeleteIncome(context, widget.income!);
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).deleteIncome(widget.income!.uuid);

      invalidateIncome(ref);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the income.');
        });
      }
    }
  }


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
                _editing ? 'Edit income' : 'Add income',
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
              // Picked from what this person has used before, or typed fresh
              // — the same control the web's income form has.
              _SourceField(
                value: _source.text,
                onChanged: (value) => setState(() => _source.text = value),
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

                        // Mirrors Currency::minimumInput — ៛100 is the smallest
                        // note in circulation.
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
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${_receivedOn.day}/${_receivedOn.month}/${_receivedOn.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(color: AppTheme.faint(context, 0.12)),
                ),
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
              if (!_editing) ...[
                const SizedBox(height: 14),
                RepeatRow(
                  value: _repeat,
                  onChanged: (value) => setState(() => _repeat = value),
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
                    : Text(
                        _editing
                            ? 'Save changes'
                            : _repeat != null
                                ? tr('Add repeating income')
                                : 'Add income',
                      ),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  child: Text(tr('Delete income')),
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
Future<bool?> confirmDeleteIncome(BuildContext context, Income income) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(tr('Delete this income?')),
      content: Text('${income.source} — ${money(income.amount)}'),
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

/// The source, as a pick-or-type field: tapping opens a sheet listing the
/// sources already used (most frequent first) with a search box that also
/// offers to use whatever is typed when nothing matches. A source is only a
/// string on each row, so "creating" one is just choosing a new string.
class _SourceField extends StatelessWidget {
  const _SourceField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final chosen = await showGlassSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SourcePickerSheet(current: value),
    );

    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: value,
      validator: (_) => value.trim().isEmpty ? 'Where did it come from?' : null,
      builder: (state) => InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        child: InputDecorator(
          decoration: InputDecoration(
            hintText: tr('Source — salary, freelance…'),
            errorText: state.errorText,
            suffixIcon: const Icon(Icons.expand_more),
          ),
          isEmpty: value.isEmpty,
          child: value.isEmpty
              ? null
              : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _SourcePickerSheet extends ConsumerStatefulWidget {
  const _SourcePickerSheet({required this.current});

  final String current;

  @override
  ConsumerState<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends ConsumerState<_SourcePickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Compared loosely, so typing "salary" against an existing "Salary" is a
  /// pick, not a new source.
  static bool _known(List<String> sources, String name) =>
      sources.any((s) => s.toLowerCase() == name.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(incomeSourcesProvider);
    final query = _search.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.pageInset, 14, AppTheme.pageInset, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Source'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr('Search or type a new source…'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (_) => setState(() {}),
                // Enter takes the typed text as-is, the fastest path for a
                // source used for the first time.
                onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.of(context).pop(v.trim()),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: sources.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(apiErrorMessage(e), textAlign: TextAlign.center),
                  ),
                  data: (list) {
                    final matches = query.isEmpty
                        ? list
                        : list.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();
                    final creatable = query.isNotEmpty && !_known(list, query) ? query : null;

                    if (matches.isEmpty && creatable == null) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          tr('No sources yet — type one above.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.faint(context, 0.5)),
                        ),
                      );
                    }

                    return ListView(
                      shrinkWrap: true,
                      children: [
                        // Only offered for what does not already exist; a
                        // match is picked instead.
                        if (creatable != null)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: Icon(Icons.add, color: AppTheme.accent(context)),
                            title: Text(
                              '${tr('Use')} "$creatable"',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () => Navigator.of(context).pop(creatable),
                          ),
                        for (final source in matches)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: Icon(Icons.payments_outlined, color: AppTheme.faint(context, 0.55)),
                            title: Text(source),
                            trailing: source.toLowerCase() == widget.current.trim().toLowerCase()
                                ? Icon(Icons.check_circle, color: AppTheme.accent(context))
                                : null,
                            onTap: () => Navigator.of(context).pop(source),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
