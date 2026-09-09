import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/savings.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Put money aside, or take it back out. Pass [entry] to edit an existing
/// movement; [type] preselects the toggle on a new one. [month] only seeds the
/// date, so adding from a month being browsed lands in that month rather than
/// today — the entry itself belongs to whatever date is chosen.
Future<void> showSavingsEntrySheet(
  BuildContext context, {
  SavingsEntry? entry,
  String type = 'deposit',
  String? month,
}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _EntryForm(entry: entry, initialType: type, month: month),
    ),
  );
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({this.entry, required this.initialType, this.month});

  final SavingsEntry? entry;
  final String initialType;
  final String? month;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.entry?.amount ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');

  late String _type = widget.entry?.type ?? widget.initialType;
  late DateTime _savedOn = _initialDate();

  /// What the *entered* amount is denominated in; storage is always USD.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  bool get _editing => widget.entry != null;

  /// The entry's own date when editing; otherwise today, or — while a past
  /// month is on screen — that month's first day, so the row lands where the
  /// list that opened the sheet can show it.
  DateTime _initialDate() {
    final saved = widget.entry?.savedOn;
    if (saved != null && saved.isNotEmpty) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) return parsed;
    }

    final today = DateTime.now();
    final month = widget.month;
    if (month != null && month != currentYm()) {
      final first = DateTime.tryParse('$month-01');
      // A future month has no valid day; the API rejects those, so stay today.
      if (first != null && first.isBefore(today)) return first;
    }

    return today;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _savedOn,
      firstDate: DateTime(2020),
      // Entries cannot be dated in the future; the API 422s them.
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => _savedOn = picked);
  }

  /// Deleting from the sheet as well as by long-press: someone who opened an
  /// entry to fix it often finds it should not exist at all, and a gesture
  /// they have to already know about is not an answer to that.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(widget.entry!.isDeposit
            ? tr('Delete this deposit?')
            : tr('Delete this withdrawal?')),
        content: Text(
          '${money(widget.entry!.amount)} · ${dayLabel(widget.entry!.savedOn)}',
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

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).deleteSavingsEntry(widget.entry!.uuid);

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the entry.');
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final note = _note.text.trim();
    final repo = ref.read(repositoryProvider);

    try {
      if (_editing) {
        await repo.updateSavingsEntry(
          widget.entry!.uuid,
          type: _type,
          amount: _amount.text.trim(),
          savedOn: dateParam(_savedOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      } else {
        await repo.addSavingsEntry(
          type: _type,
          amount: _amount.text.trim(),
          savedOn: dateParam(_savedOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      }

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop();
      }
    } catch (e) {
      // An over-withdrawal is a 422 whose errors.amount says exactly why;
      // apiErrorMessage surfaces that line verbatim.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not save the entry.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final withdrawing = _type == 'withdraw';

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
                _editing ? tr('Edit entry') : tr('New savings entry'),
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
              Row(
                children: [
                  Expanded(
                    child: PillSegment(
                      label: tr('Deposit'),
                      selected: !withdrawing,
                      onTap: () => setState(() => _type = 'deposit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PillSegment(
                      label: tr('Withdraw'),
                      selected: withdrawing,
                      onTap: () => setState(() => _type = 'withdraw'),
                    ),
                  ),
                ],
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
                      autofocus: !_editing,
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
                      setState(() {
                        _currency = selection.first;
                        // The prefilled amount is the stored USD figure;
                        // keeping it under a ៛ prefix would store it as riel.
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
                  '${_savedOn.day}/${_savedOn.month}/${_savedOn.year}',
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
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing
                        ? tr('Save changes')
                        : (withdrawing ? tr('Withdraw') : tr('Deposit'))),
              ),
              if (_editing) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  label: Text(tr('Delete entry')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
