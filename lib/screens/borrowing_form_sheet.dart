import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/borrowing.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'borrowings_screen.dart';

/// What the sheet did, for the page that opened it: the detail page leaves
/// once the borrowing it was showing has been deleted.
enum BorrowingFormResult { saved, deleted }

/// Add / edit one borrowing in a bottom sheet. Pass [borrowing] to edit.
/// On save the list, the summary, every open detail page and the lender
/// picker are invalidated.
Future<BorrowingFormResult?> showBorrowingForm(
  BuildContext context, {
  Borrowing? borrowing,
}) {
  return showGlassSheet<BorrowingFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _BorrowingForm(borrowing: borrowing),
    ),
  );
}

class _BorrowingForm extends StatefulWidget {
  const _BorrowingForm({this.borrowing});

  final Borrowing? borrowing;

  @override
  State<_BorrowingForm> createState() => _BorrowingFormState();
}

class _BorrowingFormState extends State<_BorrowingForm> {
  final _formKey = GlobalKey<FormState>();
  late final _lender = TextEditingController(
    text: widget.borrowing?.lender ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.borrowing?.amount ?? '',
  );
  late final _note = TextEditingController(text: widget.borrowing?.note ?? '');

  late String _lenderType = widget.borrowing?.lenderType ?? lenderTypes.first;
  late DateTime _borrowedOn =
      _parse(widget.borrowing?.borrowedOn) ?? DateTime.now();

  /// Optional: a loan from a friend rarely has one.
  late DateTime? _dueOn = _parse(widget.borrowing?.dueOn);

  /// What the *entered* amount is denominated in; storage is always USD,
  /// converted server-side. Editing starts from USD, since that is what the
  /// stored figure is in whatever it was typed in.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  bool get _editing => widget.borrowing != null;

  /// What has already been repaid against it — the floor for the amount on
  /// an edit. Zero on a new one.
  double get _repaid => double.tryParse(widget.borrowing?.repaid ?? '') ?? 0;

  static DateTime? _parse(String? date) =>
      date == null || date.isEmpty ? null : DateTime.tryParse(date);

  @override
  void dispose() {
    _lender.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickBorrowedOn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _borrowedOn,
      firstDate: DateTime(2020),
      // The API refuses a borrowing dated in the future.
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _borrowedOn = picked;
      // A due date before the borrowing is a 422; rather than send one, drop
      // it and let the person pick again.
      if (_dueOn != null && _dueOn!.isBefore(picked)) _dueOn = null;
    });
  }

  Future<void> _pickDueOn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn ?? _borrowedOn,
      // Not before the money changed hands — and a due date may well be far
      // in the future, which is what one is for.
      firstDate: _borrowedOn,
      lastDate: DateTime(_borrowedOn.year + 30),
    );

    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // All captured before the write: `context` must not be touched across an
    // await, and the refresh must still land if this sheet is gone by then.
    final repo = context.read<SpendLogRepository>();
    final refresh = borrowingsInvalidator(context);
    final note = _note.text.trim();
    final dueOn = _dueOn;

    try {
      if (_editing) {
        await repo.updateBorrowing(
          widget.borrowing!.uuid,
          lender: _lender.text.trim(),
          lenderType: _lenderType,
          amount: _amount.text.trim(),
          borrowedOn: dateParam(_borrowedOn),
          dueOn: dueOn == null ? null : dateParam(dueOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      } else {
        await repo.createBorrowing(
          lender: _lender.text.trim(),
          lenderType: _lenderType,
          amount: _amount.text.trim(),
          borrowedOn: dateParam(_borrowedOn),
          dueOn: dueOn == null ? null : dateParam(dueOn),
          note: note.isEmpty ? null : note,
          currency: _currency,
        );
      }

      refresh();
      if (mounted) Navigator.of(context).pop(BorrowingFormResult.saved);
    } catch (e) {
      // An amount below what is repaid is a 422 whose errors.amount says
      // exactly why; apiErrorMessage surfaces that line verbatim.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Could not save the borrowing.',
          );
        });
      }
    }
  }

  /// Deleting from the sheet, alongside the list's long-press — nothing on
  /// the row advertises the long-press, so the edit form offers the same in
  /// the open.
  Future<void> _delete() async {
    final confirmed = await confirmDeleteBorrowing(context, widget.borrowing!);
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Captured before the delete — see _submit.
    final repo = context.read<SpendLogRepository>();
    final refresh = borrowingsInvalidator(context);

    try {
      await repo.deleteBorrowing(widget.borrowing!.uuid);

      // Pop before the invalidate lands: the detail page beneath leaves on
      // this result, and should not first refetch a row that is gone.
      if (mounted) Navigator.of(context).pop(BorrowingFormResult.deleted);
      refresh();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Could not delete the borrowing.',
          );
        });
      }
    }
  }

  /// Rewrite the typed amount for the new currency rather than dropping it.
  /// Falls back to clearing only when the rate has not arrived, which is the
  /// one case where keeping the number would be a lie about how much money
  /// it is.
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

  String _dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final dueOn = _dueOn;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _editing ? tr('Edit borrowing') : tr('Add borrowing'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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
                // Typed freely, with the names used before offered as you
                // go — a lender is only ever the string on each row.
                _LenderField(controller: _lender),
                const SizedBox(height: 14),
                // Five pills, wrapping: the same control as the deposit /
                // withdraw toggle, so the app has one way to pick one of a few.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in lenderTypes)
                      IntrinsicWidth(
                        child: PillSegment(
                          label: tr(lenderTypeLabel(type)),
                          selected: _lenderType == type,
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          onTap: () => setState(() => _lenderType = type),
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final parsed = double.tryParse(v?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter an amount.';
                          }

                          // Mirrors Currency::minimumInput — ៛100 is the
                          // smallest note in circulation.
                          if (_currency == 'KHR' && parsed < 100) {
                            return 'At least ៛100.';
                          }

                          // The server refuses this too; saying it here
                          // spares the round trip. Only checked in dollars,
                          // where the two figures are in the same unit.
                          if (_currency == 'USD' && parsed < _repaid) {
                            return '${tr('Already repaid')}: ${money(widget.borrowing!.repaid)}';
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
                if (_editing && _repaid > 0) ...[
                  const SizedBox(height: 8),
                  // The floor for the amount: it cannot drop below what has
                  // already been paid back against it.
                  Text(
                    '${tr('Already repaid')}: ${money(widget.borrowing!.repaid)} — '
                    '${tr('the amount cannot go below it.')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.faint(context, 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _DateButton(
                  icon: Icons.calendar_today_outlined,
                  label: '${tr('Borrowed on')} · ${_dateLabel(_borrowedOn)}',
                  onTap: _pickBorrowedOn,
                ),
                const SizedBox(height: 10),
                _DateButton(
                  icon: Icons.event_outlined,
                  label: dueOn == null
                      ? tr('Due date (optional)')
                      : '${tr('Due on')} · ${_dateLabel(dueOn)}',
                  muted: dueOn == null,
                  onTap: _pickDueOn,
                  // Cleared with the ×, since a picker cannot pick "none".
                  onClear: dueOn == null
                      ? null
                      : () => setState(() => _dueOn = null),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _note,
                  decoration: InputDecoration(hintText: tr('Note (optional)')),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 500,
                  // The counter would sit oddly under a pill field; the limit
                  // still applies.
                  buildCounter: (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _editing ? tr('Save changes') : tr('Add borrowing'),
                        ),
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
                    label: Text(tr('Delete borrowing')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stadium button showing a date, the way every form here picks one. With
/// [onClear] it grows an × for the optional date that can be unset.
class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        foregroundColor: muted ? AppTheme.faint(context, 0.5) : ink,
        side: BorderSide(color: AppTheme.faint(context, 0.12)),
        padding: const EdgeInsets.only(left: 24, right: 8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: tr('Clear due date'),
            )
          else
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// Who lent it: type freely, with the names used before offered as you go.
/// Same control as the savings sheet's "where from" — the suggestions are a
/// convenience, not a constraint.
class _LenderField extends StatefulWidget {
  const _LenderField({required this.controller});

  final TextEditingController controller;

  @override
  State<_LenderField> createState() => _LenderFieldState();
}

class _LenderFieldState extends State<_LenderField> {
  /// Owned here, not built in `build`: RawAutocomplete keeps a reference to
  /// it, and a fresh node each frame drops focus mid-typing and leaks the
  /// old one.
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A failed or pending fetch leaves an ordinary text field, never a
    // spinner or an error: suggestions going missing must not block the form.
    final lenders =
        context.watch<BorrowingLendersNotifier>().state.valueOrNull?.lenders ??
        const <String>[];

    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (lenders.isEmpty) return const Iterable<String>.empty();

        return query.isEmpty
            ? lenders
            : lenders.where((s) => s.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: tr('Lender — e.g. Mom, Sokha, ABA Bank'),
            prefixIcon: Icon(
              Icons.person_outline,
              size: 18,
              color: AppTheme.faint(context, 0.45),
            ),
          ),
          maxLength: 255,
          textCapitalization: TextCapitalization.words,
          buildCounter: (
            _, {
            required currentLength,
            required isFocused,
            maxLength,
          }) => null,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? tr('Who lent it?') : null,
          onFieldSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              // Bounded, or a long list would run off the sheet.
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      dense: true,
                      title: Text(option),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
