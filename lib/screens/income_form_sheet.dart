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
              TextFormField(
                controller: _source,
                decoration: InputDecoration(hintText: tr('Source — salary, freelance…')),
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_editing,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Where did it come from?' : null,
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
                      setState(() {
                        _currency = selection.first;
                        // On edit the field holds the *stored* USD figure;
                        // relabelling it ៛ would store it back as riel. No
                        // endpoint exposes the rate, so clearing is the honest
                        // option — same as the budget form.
                        if (_editing) _amount.clear();
                      });
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
