import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The appearance choice: system / light / dark, remembered across launches.
///
/// Rides in the same secure storage as the token purely for convenience — it
/// is not a secret, the store is just already there and already async-safe.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    _restore();

    return ThemeMode.system;
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null) {
        state = ThemeMode.values.firstWhere(
          (mode) => mode.name == saved,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {
      // A first launch, or a platform without the store in tests — the
      // default is already right.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;

    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {
      // Not persisting is a smaller failure than crashing the toggle.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
