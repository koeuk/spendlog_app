import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/l10n.dart';
import '../models/admin.dart';
import '../models/preferences.dart';
import '../providers/async_notifier.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../repositories/spendlog_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Settings → General → Currency and Colours: one account's own choices,
/// open to everyone. Each overrides what the admin set under Settings → App,
/// for this account only; "App default" hands the choice back to the admin.

/// Saves [fields] and spreads the result: onto the signed-in user, which the
/// theme reads its colours from, and into the money settings, which every
/// amount field reads its starting currency from.
Future<void> _savePreferences(
  BuildContext context,
  Map<String, String?> fields,
) async {
  // Captured before the write: `context` must not be touched across an await.
  final repository = context.read<SpendLogRepository>();
  final auth = context.read<AuthNotifier>();
  final preferences = context.read<PreferencesNotifier>();
  final money = context.read<MoneySettingsNotifier>();
  final messenger = ScaffoldMessenger.of(context);

  try {
    final saved = await repository.updatePreferences(fields);
    final user = auth.state.user;
    if (user != null) auth.setUser(user.copyWith(preferences: saved.own));
    preferences.invalidate();
    money.invalidate();
    messenger.showSnackBar(SnackBar(content: Text(tr('Settings saved.'))));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
  }
}

/// The frame both pages share: the bar, pull-to-refresh, and the three-state
/// render of the account's preferences.
class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({required this.title, required this.builder});

  final String title;
  final Widget Function(Preferences data) builder;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<PreferencesNotifier>();
    final AsyncState<Preferences> state =
        context.watch<PreferencesNotifier>().state;

    return Scaffold(
      appBar: AppBar(leading: glassBack(context), title: Text(title)),
      body: RefreshIndicator(
        color: AppTheme.accent(context),
        onRefresh: notifier.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            8,
            AppTheme.pageInset,
            AppTheme.navBarClearance,
          ),
          children: [
            state.when(
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
                onRetry: notifier.invalidate,
              ),
              data: builder,
            ),
          ],
        ),
      ),
    );
  }
}

/// Which currency this account's amount fields start on. Saves on the tap.
class CurrencyPreferenceScreen extends StatelessWidget {
  const CurrencyPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rate = context.watch<MoneySettingsNotifier>().state.valueOrNull;

    return _PreferencesPage(
      title: tr('Currency'),
      builder: (data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Eyebrow(tr('Currency')),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'app', label: Text(tr('App default'))),
                  const ButtonSegment(value: 'USD', label: Text('USD')),
                  const ButtonSegment(value: 'KHR', label: Text('KHR')),
                ],
                selected: {data.own.currency ?? 'app'},
                onSelectionChanged: (selection) => _savePreferences(context, {
                  'currency': selection.first == 'app' ? null : selection.first,
                }),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'Amount fields start on this currency. Riel still converts at :rate per dollar.',
                ).replaceAll(
                  ':rate',
                  (rate?.khrPerUsd ?? 4100).toStringAsFixed(0),
                ),
                style: TextStyle(color: AppTheme.faint(context, 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This account's own button and background colours, over the app's.
class ColourPreferenceScreen extends StatelessWidget {
  const ColourPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) => _PreferencesPage(
        title: tr('Colours'),
        builder: (data) => _ColoursForm(
          key: ValueKey('${data.own.buttonColor}-${data.own.bodyColor}'),
          preferences: data,
        ),
      );
}

class _ColoursForm extends StatefulWidget {
  const _ColoursForm({super.key, required this.preferences});

  final Preferences preferences;

  @override
  State<_ColoursForm> createState() => _ColoursFormState();
}

class _ColoursFormState extends State<_ColoursForm> {
  // Null is "follow the app": no swatch is ticked until one is picked.
  late String? _button = widget.preferences.own.buttonColor;
  late String? _body = widget.preferences.own.bodyColor;
  bool _busy = false;

  Future<void> _save(Map<String, String?> fields) async {
    setState(() => _busy = true);
    await _savePreferences(context, fields);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final own = widget.preferences.own;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Eyebrow(tr('Colours')),
            const SizedBox(height: 8),
            Text(
              tr('Your own colours, for you only. Everyone else keeps the app’s.'),
              style: TextStyle(color: AppTheme.faint(context, 0.6)),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Button colour'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            _Swatches(
              presets: widget.preferences.buttonPresets,
              value: _button,
              onChanged: (value) => setState(() => _button = value),
            ),
            const SizedBox(height: 20),
            Text(
              tr('Background'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            _Swatches(
              presets: widget.preferences.bodyPresets,
              value: _body,
              onChanged: (value) => setState(() => _body = value),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || (_button == null && _body == null)
                  ? null
                  : () => _save({'button_color': _button, 'body_color': _body}),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(tr('Save colours')),
            ),
            if (own.hasOwnColours) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _save({'button_color': null, 'body_color': null}),
                child: Text(tr('Use the app’s colours')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round colour chips; the chosen one is ringed in ink and ticked.
class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.presets,
    required this.value,
    required this.onChanged,
  });

  final List<ColorPreset> presets;
  final String? value;
  final ValueChanged<String> onChanged;

  static Color _parse(String hex) =>
      Color(int.parse('ff${hex.substring(1)}', radix: 16));

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final preset in presets)
          Tooltip(
            message: preset.label,
            child: GestureDetector(
              onTap: () => onChanged(preset.value),
              child: Builder(
                builder: (context) {
                  final chosen =
                      value?.toLowerCase() == preset.value.toLowerCase();
                  final fill = _parse(preset.value);

                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: chosen ? ink : AppTheme.faint(context, 0.15),
                        width: chosen ? 2.5 : 1,
                      ),
                    ),
                    child: chosen
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: fill.computeLuminance() > 0.45
                                ? const Color(0xFF171717)
                                : Colors.white,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
