import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/borrowing.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';

/// Money paid back against one borrowing. The amount is capped at what is
/// still owed — the server refuses more, under a row lock — and the ceiling
/// is said here so the refusal is rarely needed.
Future<void> showBorrowingRepaymentSheet(
  BuildContext context, {
  required Borrowing borrowing,
}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _RepaymentForm(borrowing: borrowing),
    ),
  );
}

class _RepaymentForm extends StatefulWidget {
  const _RepaymentForm({required this.borrowing});

  final Borrowing borrowing;

  @override
  State<_RepaymentForm> createState() => _RepaymentFormState();
}

class _RepaymentFormState extends State<_RepaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  DateTime _paidOn = DateTime.now();

  /// What the *entered* amount is denominated in; storage is always USD.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  double get _remaining => double.tryParse(widget.borrowing.remaining) ?? 0;

  /// Nothing can be paid back before it was borrowed; the picker starts
  /// there rather than offering days the API will refuse.
  DateTime get _borrowedOn =>
      DateTime.tryParse(widget.borrowing.borrowedOn) ?? DateTime(2020);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOn,
      firstDate: _borrowedOn,
      lastDate: now,
    );

    if (picked != null) setState(() => _paidOn = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Both captured before the write: `context` must not be touched across
    // an await, and the refresh must still land if this sheet is gone by then.
    final repo = context.read<SpendLogRepository>();
    final refresh = borrowingsInvalidator(context);
    final note = _note.text.trim();

    try {
      await repo.addBorrowingRepayment(
        widget.borrowing.uuid,
        amount: _amount.text.trim(),
        paidOn: dateParam(_paidOn),
        note: note.isEmpty ? null : note,
        currency: _currency,
      );

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // More than is owed is a 422 whose errors.amount says exactly why;
      // apiErrorMessage surfaces that line verbatim.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Could not record the repayment.',
          );
        });
      }
    }
  }

  /// Rewrite the typed amount for the new currency rather than dropping it —
  /// see the other sheets for why.
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
    final faint = AppTheme.faint(context, 0.5);

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
                tr('Record repayment'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.borrowing.lender,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: faint),
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
                      controller: _amount,
                      decoration: InputDecoration(
                        hintText: tr('Amount'),
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an amount.';
                        }
                        if (_currency == 'KHR' && parsed < 100) {
                          return 'At least ៛100.';
                        }

                        // The server caps it too; saying so here spares the
                        // round trip. Only in dollars, where the two figures
                        // are in the same unit.
                        if (_currency == 'USD' && parsed > _remaining) {
                          return '${tr('Up to')} ${money(widget.borrowing.remaining)}';
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
              const SizedBox(height: 8),
              // Says the ceiling before the server has to refuse it.
              Text(
                '${tr('Still owed')}: ${money(widget.borrowing.remaining)}'
                '${_currency == 'KHR' ? ' · ${tr('Entered in riel, stored in US dollars.')}' : ''}',
                style: TextStyle(fontSize: 12, color: faint),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${tr('Paid on')} · ${_paidOn.day}/${_paidOn.month}/${_paidOn.year}',
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
                    : Text(tr('Record repayment')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
