import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/l10n.dart';

/// The language choice, remembered across launches like the theme mode.
/// Mirrored into [L10n.locale] so `tr()` needs no context, and watched by
/// the repository so server-side text is fetched again in the new language.
class LocaleNotifier extends Notifier<String> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'locale';

  @override
  String build() {
    _restore();

    return L10n.locale;
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && L10n.supported.contains(saved)) {
        L10n.locale = saved;
        state = saved;
      }
    } catch (_) {
      // A first launch, or a platform without the store: English is right.
    }
  }

  Future<void> set(String code) async {
    if (!L10n.supported.contains(code)) return;

    L10n.locale = code;
    state = code;

    try {
      await _storage.write(key: _key, value: code);
    } catch (_) {
      // Not persisting is a smaller failure than crashing the switch.
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);
