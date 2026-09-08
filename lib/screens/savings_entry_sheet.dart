import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/savings.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Put money into, or take it out of, one goal. [type] preselects the toggle
/// — deposit | withdraw — so the two buttons on the goal screen open the same
/// sheet already set the right way.
Future<void> showSavingsEntrySheet(
  BuildContext context, {
  required SavingsGoal goal,
  String type = 'deposit',
}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _EntryForm(goal: goal, initialType: type),
    ),
  );
}

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({required this.goal, required this.initialType});

  final SavingsGoal goal;
  final String initialType;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  late String _type = widget.initialType;
  DateTime _savedOn = DateTime.now();
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final note = _note.text.trim();

    try {
      await ref.read(repositoryProvider).addSavingsEntry(
            widget.goal.uuid,
            type: _type,
            amount: _amount.text.trim(),
            savedOn: dateParam(_savedOn),
            note: note.isEmpty ? null : note,
            currency: _currency,
          );

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop();
      }
    } catch (e) {
      // An over-withdrawal is a 422 whose errors.amount says exactly why;
      // apiErrorMessage surfaces that line verbatim.
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the entry.'));
    } finally {
      if (mounted) setState(() => _busy = false);
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
                widget.goal.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${money(widget.goal.saved)} saved of ${money(widget.goal.targetAmount)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.faint(context, 0.5)),
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
                      autofocus: true,
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
                    onSelectionChanged: (selection) =>
                        setState(() => _currency = selection.first),
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
                    : Text(withdrawing ? 'Withdraw' : 'Deposit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
