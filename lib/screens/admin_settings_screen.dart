import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../utils/async.dart';
import '../widgets/common.dart';

/// The web's Settings → Spending page plus FAQ management, for admins, split
/// across three tabs: the currency settings, the dashboard guidance, and the
/// help-page FAQs.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

enum _Tab { spending, guidance, faqs }

extension on _Tab {
  String get label => switch (this) {
    _Tab.spending => 'Spending',
    _Tab.guidance => 'Guidance',
    _Tab.faqs => 'FAQs',
  };
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  _Tab _tab = _Tab.spending;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(spendingSettingsProvider);
    final faqs = ref.watch(faqsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              4,
              AppTheme.pageInset - 6,
              12,
            ),
            child: Row(
              children: [
                for (final tab in _Tab.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PillSegment(
                        label: tab.label,
                        selected: tab == _tab,
                        onTap: () => setState(() => _tab = tab),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.green,
              onRefresh: () async {
                await refreshQuietly(
                  ref.refresh(spendingSettingsProvider.future),
                );
                await refreshQuietly(ref.refresh(faqsProvider.future));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pageInset,
                  0,
                  AppTheme.pageInset,
                  AppTheme.navBarClearance,
                ),
                children: [
                  // The form stays in the tree on every tab (rendering nothing
                  // on FAQs) so half-typed edits survive a switch between the
                  // two tabs that share it — both save through one endpoint.
                  settings.when(
                    loading: () => _tab == _Tab.faqs
                        ? const SizedBox.shrink()
                        : const SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppTheme.green,
                              ),
                            ),
                          ),
                    error: (e, _) => _tab == _Tab.faqs
                        ? const SizedBox.shrink()
                        : LoadFailed(
                            message: apiErrorMessage(e),
                            onRetry: () =>
                                ref.invalidate(spendingSettingsProvider),
                          ),
                    data: (data) => _SettingsForm(settings: data, tab: _tab),
                  ),
                  if (_tab == _Tab.faqs)
                    faqs.when(
                      loading: () => const SizedBox(
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppTheme.green,
                          ),
                        ),
                      ),
                      error: (e, _) => LoadFailed(
                        message: apiErrorMessage(e),
                        onRetry: () => ref.invalidate(faqsProvider),
                      ),
                      data: (list) => _FaqCard(faqs: list),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The spending and guidance tabs. One widget, because the server takes the
/// whole settings row in a single PUT: saving from either tab sends both.
class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings, required this.tab});

  final SpendingSettings settings;
  final _Tab tab;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _rate = TextEditingController(
    text: '${widget.settings.khrPerUsd}',
  );
  late final _warning = TextEditingController(text: widget.settings.warning);
  late final _advice = TextEditingController(text: widget.settings.advice);
  late bool _enabled = widget.settings.guidanceEnabled;
  late String _currency = widget.settings.defaultCurrency;
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    _warning.dispose();
    _advice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      await ref
          .read(repositoryProvider)
          .updateSpendingSettings(
            enabled: _enabled,
            warning: _warning.text.trim(),
            advice: _advice.text.trim(),
            khrPerUsd: double.tryParse(_rate.text.trim()),
            defaultCurrency: _currency,
          );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved.')));
        ref.invalidate(spendingSettingsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = switch (widget.tab) {
      _Tab.spending => _spendingFields(),
      _Tab.guidance => _guidanceFields(),
      _Tab.faqs => null,
    };
    if (fields == null) return const SizedBox.shrink();

    // The fields sit straight on the page, like the FAQ list beside them:
    // a panel around a two-field form was a box for the sake of a box.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...fields,
          const SizedBox(height: 20),
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
                : const Text('Save settings'),
          ),
        ],
      ),
    );
  }

  List<Widget> _spendingFields() => [
    const Eyebrow('Spending'),
    const SizedBox(height: 14),
    TextField(
      controller: _rate,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        hintText: 'Riel per dollar',
        prefixText: '៛ ',
        helperText: 'Every ៛ entry converts to USD at this rate.',
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        const Expanded(
          child: Text(
            'Default currency',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
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
  ];

  List<Widget> _guidanceFields() => [
    const Eyebrow('Dashboard guidance'),
    const SizedBox(height: 6),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppTheme.green,
      title: const Text(
        'Show the advice card',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text('On everyone\'s dashboard.'),
      value: _enabled,
      onChanged: (value) => setState(() => _enabled = value),
    ),
    if (_enabled) ...[
      TextField(
        controller: _warning,
        decoration: const InputDecoration(
          hintText: 'Warning (when over budget)',
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _advice,
        decoration: const InputDecoration(hintText: 'Advice (otherwise)'),
        maxLines: 2,
      ),
    ],
  ];
}

class _FaqCard extends ConsumerWidget {
  const _FaqCard({required this.faqs});

  final List<FaqEntry> faqs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No panel around the list: a heading on the page, then one row per
    // entry, the way every other list in the app reads.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
          child: Row(
            children: [
              const Expanded(child: Eyebrow('Help page FAQs')),
              TextButton.icon(
                onPressed: () => _showFaqSheet(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        if (faqs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'No entries yet.',
              style: TextStyle(color: AppTheme.faint(context, 0.5)),
            ),
          ),
        if (faqs.isNotEmpty)
          Card(
            // One solid panel, a hairline between rows — the same grouping
            // the Settings page uses.
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < faqs.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.faint(context, 0.06),
                      ),
                    ),
                  _FaqRow(faq: faqs[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FaqRow extends ConsumerWidget {
  const _FaqRow({required this.faq});

  final FaqEntry faq;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showFaqSheet(context, ref, faq: faq),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              size: 20,
              color: AppTheme.faint(context, 0.55),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                faq.question,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (faq.status != 'published') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'DRAFT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.faint(context, 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showFaqSheet(
  BuildContext context,
  WidgetRef ref, {
  FaqEntry? faq,
}) {
  final question = TextEditingController(text: faq?.question ?? '');
  final answer = TextEditingController(text: faq?.answer ?? '');
  var published = faq == null || faq.status == 'published';

  return showGlassSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  faq == null ? 'Add an FAQ' : 'Edit FAQ',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: question,
                  decoration: const InputDecoration(hintText: 'Question'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answer,
                  decoration: const InputDecoration(hintText: 'Answer'),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.green,
                  title: const Text('Published'),
                  value: published,
                  onChanged: (value) => setSheetState(() => published = value),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(repositoryProvider)
                          .saveFaq(
                            uuid: faq?.uuid,
                            question: question.text.trim(),
                            answer: answer.text.trim(),
                            status: published ? 'published' : 'draft',
                          );

                      ref.invalidate(faqsProvider);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    } catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(apiErrorMessage(e))),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
                if (faq != null)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(repositoryProvider).deleteFaq(faq.uuid);
                        ref.invalidate(faqsProvider);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(apiErrorMessage(e))),
                          );
                        }
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: const Text('Delete'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
