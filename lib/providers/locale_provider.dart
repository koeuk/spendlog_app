import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/l10n.dart';
import 'async_notifier.dart';

/// The language choice, remembered across launches like the theme mode.
/// Mirrored into [L10n.locale] so `tr()` needs no context, and depended on by
/// the repository so server-side text is fetched again in the new language.
class LocaleNotifier extends ValueState<String> {
  LocaleNotifier() : super(L10n.locale) {
    _restore();
  }

  static const _storage = FlutterSecureStorage();
  static const _key = 'locale';

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null && L10n.supported.contains(saved)) {
        L10n.locale = saved;
        value = saved;
      }
    } catch (_) {
      // A first launch, or a platform without the store: English is right.
    }
  }

  Future<void> set(String code) async {
    if (!L10n.supported.contains(code)) return;

    L10n.locale = code;
    value = code;

    try {
      await _storage.write(key: _key, value: code);
    } catch (_) {
      // Not persisting is a smaller failure than crashing the switch.
    }
  }
}
