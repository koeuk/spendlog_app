import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/expense.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/category_style.dart';

/// Add / edit an expense in a bottom sheet. On save the sheet closes and
/// every money figure on screen is invalidated — expenses, dashboard,
/// budgets all shift with one write.
Future<void> showExpenseForm(BuildContext context, {Expense? expense}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _ExpenseForm(expense: expense),
    ),
  );
}

const _newCategoryMarker = '__new__';

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({this.expense});

  final Expense? expense;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _item = TextEditingController(text: widget.expense?.item ?? '');
  late final _price = TextEditingController(text: widget.expense?.price ?? '');
  final _newCategory = TextEditingController();

  late String? _categoryUuid = widget.expense?.category?.uuid;
  late DateTime _spentOn = widget.expense?.spentOn != null
      ? DateTime.parse(widget.expense!.spentOn!)
      : DateTime.now();
  String _currency = 'USD';
  bool _busy = false;
  String? _error;

  bool get _editing => widget.expense != null;

  @override
  void dispose() {
    _item.dispose();
    _price.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  String get _spentOnParam =>
      '${_spentOn.year}-${_spentOn.month.toString().padLeft(2, '0')}-${_spentOn.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentOn,
      firstDate: DateTime(2020),
      // The API refuses future expenses; don't offer what it will 422.
      lastDate: DateTime.now(),
    );

    if (picked != null) setState(() => _spentOn = picked);
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
        await repo.updateExpense(
          widget.expense!.uuid,
          item: _item.text.trim(),
          price: _price.text.trim(),
          spentOn: _spentOnParam,
          categoryUuid: _categoryUuid == _newCategoryMarker ? null : _categoryUuid,
          currency: _currency,
        );
      } else {
        await repo.createExpense(
          item: _item.text.trim(),
          price: _price.text.trim(),
          spentOn: _spentOnParam,
          categoryUuid: _categoryUuid == _newCategoryMarker ? null : _categoryUuid,
          newCategory:
              _categoryUuid == _newCategoryMarker ? _newCategory.text.trim() : null,
          currency: _currency,
        );
      }

      if (mounted) {
        ref
          ..invalidate(expensesProvider)
          ..invalidate(dashboardProvider)
          ..invalidate(budgetSummaryProvider)
          ..invalidate(categoriesProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e, fallback: 'Could not save the expense.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deleting from the sheet, alongside the list's long-press. A long-press is
  /// a shortcut for people who know it is there; nothing on the row advertises
  /// it, so the edit form has to offer the same thing in the open — as the
  /// category form already does.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this expense?'),
        content: Text('${widget.expense!.item} — ${money(widget.expense!.price)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
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
      await ref.read(repositoryProvider).deleteExpense(widget.expense!.uuid);

      ref
        ..invalidate(expensesProvider)
        ..invalidate(dashboardProvider)
        ..invalidate(budgetSummaryProvider)
        ..invalidate(reportProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the expense.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

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
                _editing ? 'Edit expense' : 'Add an expense',
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
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _item,
                decoration: const InputDecoration(hintText: 'What was it?'),
                textCapitalization: TextCapitalization.sentences,
                autofocus: !_editing,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name the expense.' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: InputDecoration(
                        hintText: 'Price',
                        prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final parsed = double.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 0) return 'Enter a price.';

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // What the *entered* amount is denominated in; storage is
                  // always USD, converted server-side.
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'USD', label: Text('\$')),
                      ButtonSegment(value: 'KHR', label: Text('៛')),
                    ],
                    selected: {_currency},
                    onSelectionChanged: (selection) =>
                        setState(() => _currency = selection.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? AppTheme.green
                            : Colors.white,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.white
                            : AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              categories.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.green),
                    ),
                  ),
                ),
                error: (e, _) => Text(apiErrorMessage(e)),
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _categoryUuid,
                  decoration: const InputDecoration(hintText: 'Category'),
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
                    if (!_editing)
                      const DropdownMenuItem(
                        value: _newCategoryMarker,
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18, color: AppTheme.green),
                            SizedBox(width: 10),
                            Text('New category…'),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryUuid = value),
                  validator: (v) => v == null ? 'Pick a category.' : null,
                ),
              ),
              if (_categoryUuid == _newCategoryMarker) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newCategory,
                  decoration: const InputDecoration(hintText: 'New category name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => _categoryUuid == _newCategoryMarker &&
                          (v == null || v.trim().isEmpty)
                      ? 'Name the category.'
                      : null,
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${_spentOn.day}/${_spentOn.month}/${_spentOn.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                  foregroundColor: AppTheme.ink,
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_editing ? 'Save changes' : 'Add expense'),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Delete expense'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
