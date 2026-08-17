import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/category.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../utils/category_style.dart';
import '../widgets/common.dart';

/// The category list, and the form behind it for accounts that may write.
///
/// Writes need the `categories:write` ability *and* the admin policy. A
/// non-admin's token never carries the ability, so the controls are hidden
/// rather than offered and then refused with a 403.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final canWrite = ref.watch(authProvider).user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Categories',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: canWrite
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.fabNavBarOffset),
              child: FloatingActionButton.extended(
                onPressed: () => showCategoryForm(context),
                backgroundColor: AppTheme.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            )
          : null,
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        data: (list) => RefreshIndicator(
          color: AppTheme.green,
          onRefresh: () => refreshQuietly(ref.refresh(categoriesProvider.future)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, AppTheme.navBarClearance + 72),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'No categories yet.',
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              for (final category in list) ...[
                _CategoryTile(
                  category: category,
                  onTap: canWrite ? () => showCategoryForm(context, category: category) : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, this.onTap});

  final Category category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryStyle.color(category.color);
    final count = category.expensesCount;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CategoryStyle.icon(category.icon), size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (count != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        count == 1 ? '1 expense' : '$count expenses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.black.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create or edit one category.
Future<void> showCategoryForm(BuildContext context, {Category? category}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CategoryForm(category: category),
    ),
  );
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({this.category});

  final Category? category;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name ?? '');

  late String _color = widget.category?.color ?? CategoryStyle.colorNames.first;
  late String _icon = widget.category?.icon ?? CategoryStyle.iconNames.first;

  bool _busy = false;
  String? _error;

  bool get _editing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    // A renamed or recoloured category shows up on every screen that draws one.
    invalidateMoney(ref);
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
        await repo.updateCategory(
          widget.category!.uuid,
          name: _name.text.trim(),
          color: _color,
          icon: _icon,
        );
      } else {
        await repo.createCategory(name: _name.text.trim(), color: _color, icon: _icon);
      }

      _refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not save the category.');
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this category?'),
        content: Text('"${widget.category!.name}" will be removed.'),
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

    setState(() => _busy = true);

    try {
      await ref.read(repositoryProvider).deleteCategory(widget.category!.uuid);
      _refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        // A category still holding expenses or budgets comes back as a 409
        // with a message naming it — worth showing verbatim.
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not delete the category.');
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
                _editing ? 'Edit category' : 'New category',
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
                controller: _name,
                decoration: const InputDecoration(hintText: 'Name'),
                textCapitalization: TextCapitalization.words,
                autofocus: !_editing,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name the category.' : null,
              ),
              const SizedBox(height: 18),
              const Eyebrow('Colour'),
              const SizedBox(height: 10),
              _ColorPicker(
                selected: _color,
                onSelected: (value) => setState(() => _color = value),
              ),
              const SizedBox(height: 18),
              const Eyebrow('Icon'),
              const SizedBox(height: 10),
              _IconPicker(
                selected: _icon,
                color: CategoryStyle.color(_color),
                onSelected: (value) => setState(() => _icon = value),
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
                    : Text(_editing ? 'Save changes' : 'Create category'),
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _delete,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  child: const Text('Delete category'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final name in CategoryStyle.colorNames)
          GestureDetector(
            onTap: () => onSelected(name),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: CategoryStyle.color(name),
                shape: BoxShape.circle,
                border: Border.all(
                  color: name == selected ? AppTheme.ink : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: name == selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Thirty icons would push the form's buttons off screen, so the grid gets a
    // fixed height and scrolls within itself.
    return SizedBox(
      height: 140,
      child: GridView.count(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: EdgeInsets.zero,
        children: [
          for (final name in CategoryStyle.iconNames)
            GestureDetector(
              onTap: () => onSelected(name),
              child: Container(
                decoration: BoxDecoration(
                  color: name == selected
                      ? color.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: name == selected ? color : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: Icon(
                  CategoryStyle.icon(name),
                  size: 19,
                  color: name == selected ? color : Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
