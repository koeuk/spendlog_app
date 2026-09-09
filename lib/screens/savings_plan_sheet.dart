import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';

/// Set, change or clear how much the month means to put aside. The POST is an
/// upsert, so the sheet never needs to know whether the row already exists —
/// except for Clear, which needs its uuid from GET /savings/plan.
Future<void> showSavingsPlanSheet(
  BuildContext context, {
  required String month,
  String? planned,
}) {
  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _PlanForm(month: month, planned: planned),
    ),
  );
}

/// A widget rather than a bare builder so the sheet owns its controller, its
/// form state and its own `ref` — borrowing the card's would outlive the card
/// whenever the screen rebuilt underneath.
class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({required this.month, this.planned});

  final String month;

  /// The stored amount, prefilled. Null or "0.00" means no plan yet.
  final String? planned;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: (double.tryParse(widget.planned ?? '') ?? 0) > 0 ? widget.planned : '',
  );

  /// What the *entered* amount is denominated in. Storage is always USD,
  /// converted server-side — see App\Enums\Currency in the backend.
  String _currency = 'USD';

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(repositoryProvider).setSavingsPlan(
            month: widget.month,
            amount: _amount.text.trim(),
            currency: _currency,
          );

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop();
      }
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

    try {
      await ref.read(repositoryProvider).deleteSavingsPlan(uuid);

      if (mounted) {
        invalidateSavings(ref);
        Navigator.of(context).pop();
      }
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
    final plan = ref.watch(savingsPlanProvider(widget.month)).valueOrNull;

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
                '${tr('Savings plan')} — ${monthLabel(widget.month)}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                tr('How much do you mean to put aside this month?'),
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
                    child: TextFormField(
                      controller: _amount,
                      decoration: InputDecoration(
                        hintText: tr('Amount'),
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 0) return 'Enter an amount.';

                        // Mirrors Currency::minimumInput — ៛100 is the smallest
                        // note in circulation, so anything under it is not an
                        // amount that can be paid.
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
                        // The field is prefilled with the *stored* plan, which
                        // is USD. Keeping that figure while the prefix says ៛
                        // would label $200.00 as ៛200 and store it back as five
                        // cents; no endpoint exposes the rate, so clearing is
                        // the only honest option.
                        _amount.clear();
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
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(tr('Save plan')),
              ),
              if (plan != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : () => _clear(plan.uuid),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626)),
                  child: Text(tr('Clear plan')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
