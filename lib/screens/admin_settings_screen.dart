import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../utils/async.dart';
import '../widgets/common.dart';

/// The web's Settings → Spending page plus FAQ management, for admins.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(spendingSettingsProvider);
    final faqs = ref.watch(faqsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'App settings',
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.green,
        onRefresh: () async {
          await refreshQuietly(ref.refresh(spendingSettingsProvider.future));
          await refreshQuietly(ref.refresh(faqsProvider.future));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, AppTheme.navBarClearance),
          children: [
            settings.when(
              loading: () => const SizedBox(
                height: 100,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppTheme.green)),
              ),
              error: (e, _) => LoadFailed(
                message: apiErrorMessage(e),
                onRetry: () => ref.invalidate(spendingSettingsProvider),
              ),
              data: (data) => _SpendingCard(settings: data),
            ),
            const SizedBox(height: 16),
            faqs.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(20), child: Text(apiErrorMessage(e))),
              ),
              data: (list) => _FaqCard(faqs: list),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingCard extends ConsumerStatefulWidget {
  const _SpendingCard({required this.settings});

  final SpendingSettings settings;

  @override
  ConsumerState<_SpendingCard> createState() => _SpendingCardState();
}

class _SpendingCardState extends ConsumerState<_SpendingCard> {
  late final _rate = TextEditingController(text: '${widget.settings.khrPerUsd}');
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
      await ref.read(repositoryProvider).updateSpendingSettings(
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  child: Text('Default currency',
                      style: TextStyle(fontWeight: FontWeight.w500)),
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
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppTheme.green,
              title: const Text('Dashboard guidance',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Show the advice card on everyone\'s dashboard.'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            if (_enabled) ...[
              TextField(
                controller: _warning,
                decoration: const InputDecoration(hintText: 'Warning (when over budget)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _advice,
                decoration: const InputDecoration(hintText: 'Advice (otherwise)'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqCard extends ConsumerWidget {
  const _FaqCard({required this.faqs});

  final List<FaqEntry> faqs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('Help page FAQs')),
                TextButton.icon(
                  onPressed: () => _showFaqSheet(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (faqs.isEmpty)
              Text(
                'No entries yet.',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
              ),
            for (final faq in faqs) ...[
              InkWell(
                onTap: () => _showFaqSheet(context, ref, faq: faq),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(faq.question,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      if (faq.status != 'published')
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  ),
                ),
              ),
              if (faq != faqs.last)
                Divider(height: 8, color: Colors.black.withValues(alpha: 0.05)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showFaqSheet(BuildContext context, WidgetRef ref, {FaqEntry? faq}) {
  final question = TextEditingController(text: faq?.question ?? '');
  final answer = TextEditingController(text: faq?.answer ?? '');
  var published = faq == null || faq.status == 'published';

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
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
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
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
                      await ref.read(repositoryProvider).saveFaq(
                            uuid: faq?.uuid,
                            question: question.text.trim(),
                            answer: answer.text.trim(),
                            status: published ? 'published' : 'draft',
                          );

                      ref.invalidate(faqsProvider);
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    } catch (e) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text(apiErrorMessage(e))));
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
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      } catch (e) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(apiErrorMessage(e))));
                        }
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
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
