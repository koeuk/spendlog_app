import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/recurring.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../utils/format.dart';
import '../utils/category_style.dart';

/// Add / edit an expense on its own page. On save the page closes and every
/// money figure on screen is invalidated — expenses, dashboard, budgets all
/// shift with one write.
Future<void> showExpenseForm(BuildContext context, {Expense? expense}) {
  return openFormPage<void>(context, (_) => _ExpenseForm(expense: expense));
}

const _newCategoryMarker = '__new__';

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({this.expense});

  final Expense? expense;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _item = TextEditingController(text: widget.expense?.item ?? '');
  late final _price = TextEditingController(text: widget.expense?.price ?? '');
  final _newCategory = TextEditingController();

  late String? _categoryUuid = widget.expense?.category?.uuid;
  late DateTime _spentOn =
      DateTime.tryParse(widget.expense?.spentOn ?? '') ?? DateTime.now();
  String _currency = 'USD';

  /// Set the moment the person moves the toggle, so a default landing late
  /// cannot overrule a currency they picked themselves.
  bool _currencyChosen = false;

  @override
  void initState() {
    super.initState();
    _startOnDefaultCurrency();
  }

  /// Start on the account's default currency rather than always on dollars.
  ///
  /// Applied when the settings land rather than at build: they are fetched
  /// lazily and a form can open before anything has asked for them. Skipped
  /// once there is an amount in the box — a stored figure is in dollars, and
  /// a default arriving behind someone's typing would relabel their number as
  /// money it is not.
  Future<void> _startOnDefaultCurrency() async {
    final settings = await context.read<MoneySettingsNotifier>().settings();
    if (!mounted || _currencyChosen || _price.text.trim().isNotEmpty) return;

    setState(() => _currency = settings?.defaultCurrency ?? 'USD');
  }

  /// A frequency from [recurringFrequencies], or null for a one-off. Only
  /// offered on create: an existing row is a row, not a rule.
  String? _repeat;

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

    // All captured before the write: `context` must not be touched across an
    // await, and the refreshes must still land if this sheet is gone by then.
    final repo = context.read<SpendLogRepository>();
    final refreshMoney = moneyInvalidator(context);
    final refreshRecurring = recurringInvalidator(context);

    try {
      if (_editing) {
        await repo.updateExpense(
          widget.expense!.uuid,
          item: _item.text.trim(),
          price: _price.text.trim(),
          spentOn: _spentOnParam,
          categoryUuid: _categoryUuid == _newCategoryMarker
              ? null
              : _categoryUuid,
          currency: _currency,
        );
      } else if (_repeat != null) {
        // A rule instead of a row: the server runs it at once, so today's
        // expense appears straight away and the rest follow on schedule.
        await repo.createRecurringRule(
          kind: 'expense',
          title: _item.text.trim(),
          amount: _price.text.trim(),
          frequency: _repeat!,
          startsOn: _spentOnParam,
          categoryUuid: _categoryUuid,
          currency: _currency,
        );
      } else {
        await repo.createExpense(
          item: _item.text.trim(),
          price: _price.text.trim(),
          spentOn: _spentOnParam,
          categoryUuid: _categoryUuid == _newCategoryMarker
              ? null
              : _categoryUuid,
          newCategory: _categoryUuid == _newCategoryMarker
              ? _newCategory.text.trim()
              : null,
          currency: _currency,
        );
      }

      refreshMoney();
      if (_repeat != null) refreshRecurring();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = apiErrorMessage(
          e,
          fallback: 'Could not save the expense.',
        ),
      );
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
        title: Text(tr('Delete this expense?')),
        content: Text(
          '${widget.expense!.item} — ${money(widget.expense!.price)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
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

    // Captured before the delete — see _submit.
    final repo = context.read<SpendLogRepository>();
    final refreshMoney = moneyInvalidator(context);

    try {
      await repo.deleteExpense(widget.expense!.uuid);

      refreshMoney();

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(
            e,
            fallback: 'Could not delete the expense.',
          );
        });
      }
    }
  }

  /// Rewrite the typed amount for the new currency rather than leaving the
  /// number and swapping the prefix — "12.50" under a ៛ is three tenths of a
  /// cent, not twelve dollars fifty. Clears only when the rate is unknown,
  /// the one case where keeping the figure would be a lie.
  Future<void> _switchCurrency(String next) async {
    _currencyChosen = true;

    // Awaited, not read: the rate may not have been fetched yet, and a toggle
    // that blanks the amount because the answer had not arrived is worse than
    // one that takes a moment. See MoneySettingsNotifier.khrPerUsd.
    final rate = await context.read<MoneySettingsNotifier>().khrPerUsd();
    if (!mounted) return;

    final converted = rate == null
        ? null
        : convertAmount(
            _price.text,
            from: _currency,
            to: next,
            khrPerUsd: rate,
          );

    setState(() {
      if (converted != null) {
        _price.text = converted;
      } else if (rate == null) {
        _price.clear();
      }
      _currency = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoriesNotifier>().state;

    return FormPage(
      title: _editing ? tr('Edit expense') : tr('Add an expense'),
      formKey: _formKey,
      children: [
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
          controller: _item,
          decoration: InputDecoration(hintText: tr('What was it?')),
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
                  hintText: tr('Price'),
                  prefixText: _currency == 'USD' ? '\$ ' : '៛ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a price.';
                  }

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
                  _switchCurrency(selection.first),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 14),
        categories.when(
          loading: () => Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent(context),
                ),
              ),
            ),
          ),
          error: (e, _) => Text(apiErrorMessage(e)),
          data: (list) => _CategoryField(
            categories: list,
            value: _categoryUuid,
            // A rule needs an existing category; the inline path is for
            // one-off rows only.
            allowNew: !_editing && _repeat == null,
            onChanged: (value) => setState(() => _categoryUuid = value),
          ),
        ),
        if (_categoryUuid == _newCategoryMarker) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _newCategory,
            decoration: InputDecoration(hintText: tr('New category name')),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                _categoryUuid == _newCategoryMarker &&
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
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(color: AppTheme.faint(context, 0.12)),
          ),
        ),
        if (!_editing) ...[
          const SizedBox(height: 14),
          RepeatRow(
            value: _repeat,
            onChanged: (value) => setState(() {
              _repeat = value;
              // The inline "new category" path is gone while repeating.
              if (value != null && _categoryUuid == _newCategoryMarker) {
                _categoryUuid = null;
              }
            }),
          ),
        ],
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
                  _editing
                      ? 'Save changes'
                      : _repeat != null
                      ? tr('Add repeating expense')
                      : 'Add expense',
                ),
        ),
        if (_editing) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            ),
            child: Text(tr('Delete expense')),
          ),
        ],
      ],
    );
  }
}

/// The category, as a pick-from-a-list field.
///
/// A sheet with a search box rather than a dropdown: an account's categories
/// run to twenty or more, and a dropdown that long is a list you scroll past
/// what you are looking for.
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.value,
    required this.allowNew,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? value;

  /// Whether the sheet offers naming a category that does not exist yet.
  final bool allowNew;

  final ValueChanged<String?> onChanged;

  Future<void> _open(BuildContext context) async {
    final chosen = await showGlassSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CategoryPickerSheet(
        categories: categories,
        current: value,
        allowNew: allowNew,
      ),
    );

    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final found = value == null || value == _newCategoryMarker
        ? const <Category>[]
        : categories.where((c) => c.uuid == value).toList();
    final picked = found.isEmpty ? null : found.first;
    final naming = value == _newCategoryMarker;

    return FormField<String>(
      // Keyed on the selection so a pick clears the error it just fixed, and
      // so validate() is never asked about a value that has been replaced.
      key: ValueKey(value),
      validator: (_) => value == null ? 'Pick a category.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(AppTheme.rowRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: field.errorText,
                // The row below carries the message, so the decorator only
                // needs the red edge the error state gives it.
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
              child: Row(
                children: [
                  if (picked != null) ...[
                    Icon(
                      CategoryStyle.icon(picked.icon),
                      size: 18,
                      color: CategoryStyle.color(picked.color),
                    ),
                    const SizedBox(width: 10),
                  ] else if (naming) ...[
                    Icon(Icons.add, size: 18, color: AppTheme.accent(context)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      picked?.name ??
                          (naming ? tr('New category…') : tr('Category')),
                      overflow: TextOverflow.ellipsis,
                      style: picked == null && !naming
                          ? TextStyle(color: AppTheme.faint(context, 0.5))
                          : null,
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppTheme.faint(context, 0.4),
                  ),
                ],
              ),
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.errorInk(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The list behind [_CategoryField], filtered as you type.
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.current,
    required this.allowNew,
  });

  final List<Category> categories;
  final String? current;
  final bool allowNew;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? widget.categories
        : widget.categories
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            14,
            AppTheme.pageInset,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Category'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('Search categories…'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (_) => setState(() {}),
                // Enter takes the only thing left, which is what a search
                // narrowed to one result is asking for.
                onSubmitted: (_) => matches.length == 1
                    ? Navigator.of(context).pop(matches.single.uuid)
                    : null,
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: matches.isEmpty && !widget.allowNew
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          tr('Nothing matches that.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.faint(context, 0.5)),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final category in matches)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                CategoryStyle.icon(category.icon),
                                size: 20,
                                color: CategoryStyle.color(category.color),
                              ),
                              title: Text(category.name),
                              trailing: category.uuid == widget.current
                                  ? Icon(
                                      Icons.check,
                                      size: 18,
                                      color: AppTheme.accent(context),
                                    )
                                  : null,
                              onTap: () =>
                                  Navigator.of(context).pop(category.uuid),
                            ),
                          if (widget.allowNew)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.add,
                                size: 20,
                                color: AppTheme.accent(context),
                              ),
                              title: Text(tr('New category…')),
                              onTap: () =>
                                  Navigator.of(context).pop(_newCategoryMarker),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
