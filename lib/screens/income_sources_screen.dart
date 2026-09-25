import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/income.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// The names income is filed under, and what the income and savings forms
/// offer.
///
/// A catalogue of suggestions: an income carries its source as text, so a name
/// renamed or removed here leaves the money alone unless the rename is asked
/// to carry it across. That is why a row can say "not used yet" and why
/// removing one is not destructive.
class IncomeSourcesScreen extends StatelessWidget {
  const IncomeSourcesScreen({super.key});

  static const _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<IncomeSourceCatalogNotifier>().state;

    return Scaffold(
      appBar: AppBar(
        leading: glassBack(context),
        centerTitle: false,
        title: Text(tr('Sources')),
      ),
      floatingActionButton: AddPill(
        label: tr('Add'),
        onPressed: () => showIncomeSourceSheet(context),
      ),
      body: sources.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.accent(context)),
        ),
        error: (e, _) => LoadFailed(
          message: apiErrorMessage(e),
          onRetry: () =>
              context.read<IncomeSourceCatalogNotifier>().invalidate(),
        ),
        data: (list) => RefreshIndicator(
          color: AppTheme.accent(context),

          // `refresh` never throws — see AsyncNotifier.refresh.
          onRefresh: () =>
              context.read<IncomeSourceCatalogNotifier>().refresh(),
          child: list.isEmpty
              // Still a scroll view, so pull-to-refresh works on the empty
              // state too.
              ? ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 72),
                      child: Column(
                        children: [
                          Icon(
                            Icons.sell_outlined,
                            size: 44,
                            color: AppTheme.faint(context, 0.25),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('No sources yet.'),
                            style: TextStyle(
                              color: AppTheme.faint(context, 0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              tr(
                                'One is added for you whenever you name where money came from.',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.faint(context, 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pageInset,
                    4,
                    AppTheme.pageInset,
                    AppTheme.navBarClearance + 72,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _SourceRow(
                    source: list[i],
                    onTap: () =>
                        showIncomeSourceSheet(context, source: list[i]),
                    onDelete: () => _delete(context, list[i]),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, IncomeSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(tr('Remove this source?')),
        content: Text(
          source.uses == 0
              ? tr('It is not used by anything.')
              // Said plainly: the number beside the name is the thing someone
              // is about to worry they are deleting.
              : tr(
                  'It stops being offered. The money filed under it keeps the name.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: Text(tr('Remove')),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Read before the delete: `context` must not be touched across an await.
    final repository = context.read<SpendLogRepository>();
    final refresh = incomeInvalidator(context);

    try {
      await repository.deleteIncomeSource(source.uuid);
      refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.onTap,
    required this.onDelete,
  });

  final IncomeSource source;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final used = source.uses > 0;

    return Card(
      shape: AppTheme.rowShape(context),
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(AppTheme.rowRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: used ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sell_outlined,
                  size: 20,
                  color: used ? accent : AppTheme.faint(context, 0.4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      used
                          ? '${source.uses == 1 ? tr('1 entry') : '${source.uses} ${tr('entries')}'} · ${money(source.total)}'
                          : tr('Not used yet'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.faint(context, 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.faint(context, 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add a name, or rename one, on its own page. Pass [source] to edit.
Future<void> showIncomeSourceSheet(
  BuildContext context, {
  IncomeSource? source,
}) {
  return openFormPage<void>(context, (_) => _SourceForm(source: source));
}

class _SourceForm extends StatefulWidget {
  const _SourceForm({this.source});

  final IncomeSource? source;

  @override
  State<_SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<_SourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.name ?? '');

  /// Whether a rename also rewrites the income filed under the old name.
  /// Off by default, as the API has it: rewriting history is the larger of
  /// the two acts, and the old name was often not a mistake.
  bool _rewrite = false;

  bool _busy = false;
  String? _error;

  bool get _editing => widget.source != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Both captured before the write: `context` must not be touched across an
    // await, and the refresh must still land if this sheet is gone by then.
    final repository = context.read<SpendLogRepository>();
    final refresh = incomeInvalidator(context);
    final name = _name.text.trim();

    try {
      if (_editing) {
        await repository.renameIncomeSource(
          widget.source!.uuid,
          name: name,
          rewriteIncomes: _rewrite,
        );
      } else {
        await repository.createIncomeSource(name);
      }

      refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, fallback: 'Could not save the source.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final renaming = _editing && _name.text.trim() != source!.name;

    return FormPage(
      title: _editing ? tr('Rename source') : tr('New source'),
      subtitle: tr('Offered when you say where money came from.'),
      formKey: _formKey,
      footer: [
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(tr('Save')),
        ),
      ],
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
          controller: _name,
          decoration: InputDecoration(hintText: tr('Name')),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 255,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          // Only to show or hide the switch below; the field's own text
          // is read from the controller when it is saved.
          onChanged: (_) => setState(() {}),
          validator: (v) =>
              (v?.trim().isEmpty ?? true) ? 'Enter a name.' : null,
        ),
        // Only worth asking where there is history to carry, and only
        // once the name has actually changed.
        if (renaming && source.uses > 0) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _rewrite,
            onChanged: (value) => setState(() => _rewrite = value),
            title: Text(
              source.uses == 1
                  ? tr('Rename the 1 entry filed under it')
                  : '${tr('Rename the')} ${source.uses} ${tr('entries filed under it')}',
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              tr('Leave this off to keep what was entered at the time.'),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.faint(context, 0.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}
