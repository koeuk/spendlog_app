import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/savings.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/category_style.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Create or edit one savings goal. Resolves to `true` when the goal was
/// deleted from the sheet, so a detail screen showing it knows to leave.
Future<bool?> showSavingsGoalSheet(BuildContext context, {SavingsGoal? goal}) {
  return showGlassSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _GoalForm(goal: goal),
    ),
  );
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _target = TextEditingController(text: widget.goal?.targetAmount ?? '');

  late String _color = widget.goal?.color ?? CategoryStyle.colorNames.first;
  late DateTime? _deadline =
      widget.goal?.deadline != null ? DateTime.parse(widget.goal!.deadline!) : null;

  /// What the *entered* target is denominated in; storage is always USD.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  bool get _editing => widget.goal != null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final today = DateTime.now();
    // A new goal cannot be due in the past; an existing one may already be,
    // and the picker has to be able to land on that date to show it.
    final first = _editing ? DateTime(2020) : DateTime(today.year, today.month, today.day);
    final initial = _deadline ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(today.year + 30),
    );

    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(repositoryProvider);
    final deadline = _deadline == null ? null : dateParam(_deadline!);

    try {
      if (_editing) {
        await repo.updateSavingsGoal(
          widget.goal!.uuid,
          name: _name.text.trim(),
          targetAmount: _target.text.trim(),
          deadline: deadline,
          color: _color,
          currency: _currency,
        );
      } else {
        await repo.createSavingsGoal(
          name: _name.text.trim(),
          targetAmount: _target.text.trim(),
          deadline: deadline,
          color: _color,
          currency: _currency,
        );
      }

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the goal.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final goal = widget.goal!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Delete this goal?')),
        content: Text(
          '"${goal.name}" and every deposit and withdrawal on it will be removed.',
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

    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).deleteSavingsGoal(goal.uuid);

      invalidateSavings(ref);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the goal.');
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
                _editing ? 'Edit goal' : 'New savings goal',
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
                controller: _name,
                decoration: InputDecoration(hintText: tr('What are you saving for?')),
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_editing,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name the goal.' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _target,
                      decoration: InputDecoration(
                        hintText: tr('Target'),
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed <= 0) return 'Enter a target.';
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
                        // The prefilled target is the stored USD figure; keeping
                        // it under a ៛ prefix would store it back as riel.
                        if (_editing) _target.clear();
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        _deadline == null
                            ? 'No deadline'
                            : 'By ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: AppTheme.faint(context, 0.12)),
                      ),
                    ),
                  ),
                  if (_deadline != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _deadline = null),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: tr('Clear deadline'),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        shape: const CircleBorder(),
                        side: BorderSide(color: AppTheme.faint(context, 0.12)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Eyebrow(tr('Colour')),
              const SizedBox(height: 10),
              SwatchPicker(
                selected: _color,
                onSelected: (value) => setState(() => _color = value),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing ? 'Save changes' : 'Create goal'),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  child: Text(tr('Delete goal')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
