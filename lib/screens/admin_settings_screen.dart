import 'dart:typed_data';

import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/admin.dart';
import '../providers/branding_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../utils/async.dart';
import '../widgets/common.dart';

/// The web's admin Settings pages, for admins, as tabs: the currency
/// settings, the dashboard guidance, the help-page FAQs, the app's name and
/// marks, and its colours.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

enum _Tab { spending, guidance, faqs, appearance, colours }

extension on _Tab {
  String get label => switch (this) {
    _Tab.spending => 'Spending',
    _Tab.guidance => 'Guidance',
    _Tab.faqs => 'FAQs',
    _Tab.appearance => 'Appearance',
    _Tab.colours => 'Colours',
  };

  /// Spending and Guidance edit one settings row through one endpoint, so
  /// they share a form that stays mounted across both.
  bool get sharesSpendingForm => this == _Tab.spending || this == _Tab.guidance;
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  _Tab _tab = _Tab.spending;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(spendingSettingsProvider);
    final faqs = ref.watch(faqsProvider);
    final branding = ref.watch(brandingSettingsProvider);
    final colours = ref.watch(colorSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('App settings'))),
      body: Column(
        children: [
          // Five tabs do not fit a phone as equal shares, so the row scrolls
          // and every pill keeps the same width.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(AppTheme.pageInset, 4, AppTheme.pageInset - 6, 12),
            child: Row(
              children: [
                for (final tab in _Tab.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 104,
                      child: PillSegment(
                        label: tr(tab.label),
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
              color: AppTheme.accent(context),
              onRefresh: () async {
                await refreshQuietly(
                  ref.refresh(spendingSettingsProvider.future),
                );
                await refreshQuietly(ref.refresh(faqsProvider.future));
                await refreshQuietly(ref.refresh(brandingSettingsProvider.future));
                await refreshQuietly(ref.refresh(colorSettingsProvider.future));
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
                    loading: () => !_tab.sharesSpendingForm
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppTheme.accent(context),
                              ),
                            ),
                          ),
                    error: (e, _) => !_tab.sharesSpendingForm
                        ? const SizedBox.shrink()
                        : LoadFailed(
                            message: apiErrorMessage(e),
                            onRetry: () =>
                                ref.invalidate(spendingSettingsProvider),
                          ),
                    data: (data) => _SettingsForm(settings: data, tab: _tab),
                  ),
                  if (_tab == _Tab.appearance)
                    branding.when(
                      loading: () => const _Loading(),
                      error: (e, _) => LoadFailed(
                        message: apiErrorMessage(e),
                        onRetry: () => ref.invalidate(brandingSettingsProvider),
                      ),
                      data: (data) => _BrandingForm(settings: data),
                    ),
                  if (_tab == _Tab.colours)
                    colours.when(
                      loading: () => const _Loading(),
                      error: (e, _) => LoadFailed(
                        message: apiErrorMessage(e),
                        onRetry: () => ref.invalidate(colorSettingsProvider),
                      ),
                      data: (data) => _ColoursForm(settings: data),
                    ),
                  if (_tab == _Tab.faqs)
                    faqs.when(
                      loading: () => SizedBox(
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppTheme.accent(context),
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
            .showSnackBar(SnackBar(content: Text(tr('Settings saved.'))));
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
      _ => null,
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
                : Text(tr('Save settings')),
          ),
        ],
      ),
    );
  }

  List<Widget> _spendingFields() => [
    Eyebrow(tr('Spending')),
    const SizedBox(height: 14),
    TextField(
      controller: _rate,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: tr('Riel per dollar'),
        prefixText: '៛ ',
        helperText: tr('Every ៛ entry converts to USD at this rate.'),
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: Text(
            tr('Default currency'),
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
    Eyebrow(tr('Dashboard guidance')),
    const SizedBox(height: 6),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppTheme.accent(context),
      title: Text(
        tr('Show the advice card'),
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(tr('On everyone\'s dashboard.')),
      value: _enabled,
      onChanged: (value) => setState(() => _enabled = value),
    ),
    if (_enabled) ...[
      TextField(
        controller: _warning,
        decoration: InputDecoration(
          hintText: tr('Warning (when over budget)'),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _advice,
        decoration: InputDecoration(hintText: tr('Advice (otherwise)')),
        maxLines: 2,
      ),
    ],
  ];
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.accent(context)),
        ),
      );
}

/// Settings → Appearance: the name, the footer's copyright holder, and the
/// logo and favicon. Images are picked here and only sent on Save, so backing
/// out of the tab discards them like any other unsaved field.
class _BrandingForm extends ConsumerStatefulWidget {
  const _BrandingForm({required this.settings});

  final BrandingSettings settings;

  @override
  ConsumerState<_BrandingForm> createState() => _BrandingFormState();
}

class _BrandingFormState extends ConsumerState<_BrandingForm> {
  late final _name = TextEditingController(text: widget.settings.appName);
  late final _holder = TextEditingController(text: widget.settings.copyrightHolder ?? '');

  XFile? _logo;
  XFile? _favicon;
  bool _removeLogo = false;
  bool _removeFavicon = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<XFile?> _pick() async {
    try {
      return await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Comfortably under the server's 2 MB logo cap.
        maxWidth: 1600,
        maxHeight: 1600,
      );
    } catch (_) {
      // No picker on this platform build (a desktop run that predates the
      // plugin, say): a message beats an uncaught exception.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Could not open the file picker.'))),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      final logo = _logo;
      final favicon = _favicon;

      await ref.read(repositoryProvider).updateBranding(
            appName: _name.text.trim(),
            copyrightHolder: _holder.text.trim(),
            logo: logo == null ? null : (bytes: await logo.readAsBytes(), filename: logo.name),
            favicon: favicon == null
                ? null
                : (bytes: await favicon.readAsBytes(), filename: favicon.name),
            removeLogo: _removeLogo,
            removeFavicon: _removeFavicon,
          );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('Appearance saved.'))));
        ref.invalidate(brandingSettingsProvider);
        // The app wears the new marks at once, like the web after a save.
        ref.read(brandingProvider.notifier).refresh();
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
            Eyebrow(tr('Appearance')),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: tr('App name'),
                helperText: tr('Shown in the nav bar and the browser tab.'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _holder,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: tr('Copyright holder'),
                helperText: tr('Shown in the footer. Leave blank to use the app name.'),
              ),
            ),
            const SizedBox(height: 18),
            _ImageField(
              label: tr('Logo'),
              hint: 'PNG, JPG or WebP, up to 2 MB. Any size — it is scaled to fit.',
              currentUrl: widget.settings.logoUrl,
              picked: _logo,
              removed: _removeLogo,
              onChoose: () async {
                final file = await _pick();
                if (file != null) setState(() { _logo = file; _removeLogo = false; });
              },
              onRemove: () => setState(() { _logo = null; _removeLogo = true; }),
            ),
            const SizedBox(height: 16),
            _ImageField(
              label: tr('Favicon'),
              hint: 'Shown in the browser tab. PNG, ICO, JPG or WebP, up to 1 MB. Square works best.',
              currentUrl: widget.settings.faviconUrl,
              picked: _favicon,
              removed: _removeFavicon,
              onChoose: () async {
                final file = await _pick();
                if (file != null) setState(() { _favicon = file; _removeFavicon = false; });
              },
              onRemove: () => setState(() { _favicon = null; _removeFavicon = true; }),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const _ButtonSpinner() : Text(tr('Save appearance')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A mark with Choose and Remove beside it. Shows the freshly picked file
/// ahead of the saved one, and a placeholder once Remove has been pressed.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.label,
    required this.hint,
    required this.currentUrl,
    required this.picked,
    required this.removed,
    required this.onChoose,
    required this.onRemove,
  });

  final String label;
  final String hint;
  final String? currentUrl;
  final XFile? picked;
  final bool removed;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = picked != null || (currentUrl != null && !removed);

    Widget preview;
    if (picked != null) {
      preview = FutureBuilder<List<int>>(
        future: picked!.readAsBytes(),
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(Uint8List.fromList(snapshot.data!), fit: BoxFit.contain)
            : const SizedBox.shrink(),
      );
    } else if (currentUrl != null && !removed) {
      preview = Image.network(currentUrl!, fit: BoxFit.contain);
    } else {
      preview = Icon(Icons.image_outlined, color: AppTheme.faint(context, 0.3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.glassFill(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.faint(context, 0.10)),
              ),
              child: preview,
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.photo_outlined, size: 18),
              label: Text(tr('Choose')),
            ),
            if (hasImage)
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                child: Text(tr('Remove')),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(hint, style: TextStyle(fontSize: 12, color: AppTheme.faint(context, 0.5))),
      ],
    );
  }
}

/// Settings → Colours: the button colour (a preset or any readable hex) and
/// the page background (presets only, since the whole theme derives from it).
class _ColoursForm extends ConsumerStatefulWidget {
  const _ColoursForm({required this.settings});

  final ColorSettings settings;

  @override
  ConsumerState<_ColoursForm> createState() => _ColoursFormState();
}

class _ColoursFormState extends ConsumerState<_ColoursForm> {
  late String _button = widget.settings.buttonColor;
  late String _body = widget.settings.bodyColor;
  late final _custom = TextEditingController(text: widget.settings.buttonColor);
  bool _busy = false;

  static final _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  static Color _parse(String hex) =>
      Color(int.parse('ff${hex.substring(1)}', radix: 16));

  Future<void> _save() async {
    if (!_hex.hasMatch(_button)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter a colour as #rrggbb.'))),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await ref.read(repositoryProvider).updateColors(
            buttonColor: _button.toLowerCase(),
            bodyColor: _body,
          );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('Colours saved.'))));
        ref.invalidate(colorSettingsProvider);
        ref.read(brandingProvider.notifier).refresh();
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
    final ink = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow(tr('Colours')),
            const SizedBox(height: 14),
            Text(tr('Button colour'), style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in widget.settings.buttonPresets)
                  Tooltip(
                    message: preset.isDefault ? '${preset.label} (default)' : preset.label,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _button = preset.value;
                        _custom.text = preset.value;
                      }),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parse(preset.value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _button.toLowerCase() == preset.value.toLowerCase()
                                ? ink
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _button.toLowerCase() == preset.value.toLowerCase()
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              autocorrect: false,
              onChanged: (v) => setState(() => _button = v.trim()),
              decoration: InputDecoration(
                hintText: '#rrggbb',
                helperText: tr('Or any hex that can carry a readable label.'),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _hex.hasMatch(_button) ? _parse(_button) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.faint(context, 0.2)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(tr('Background'), style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in widget.settings.bodyPresets)
                  ChoiceChip(
                    avatar: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _parse(preset.value),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.faint(context, 0.2)),
                      ),
                    ),
                    label: Text(preset.label),
                    selected: _body.toLowerCase() == preset.value.toLowerCase(),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _body = preset.value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const _ButtonSpinner() : Text(tr('Save colours')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
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
              Expanded(child: Eyebrow(tr('Help page FAQs'))),
              TextButton.icon(
                onPressed: () => _showFaqSheet(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: Text(tr('Add')),
              ),
            ],
          ),
        ),
        if (faqs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              tr('No entries yet.'),
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
                child: Text(
                  tr('DRAFT'),
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
                  decoration: InputDecoration(hintText: tr('Question')),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answer,
                  decoration: InputDecoration(hintText: tr('Answer')),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.accent(context),
                  title: Text(tr('Published')),
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
                  child: Text(tr('Save')),
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
                    child: Text(tr('Delete')),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
