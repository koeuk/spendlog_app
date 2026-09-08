import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/branding.dart';
import 'data_providers.dart';

/// The look the admin chose, driving the theme. Restored from the last run
/// first so a cold start does not flash the stock look, then refreshed from
/// the server. Rides in the same store as the token, like the theme mode.
class BrandingNotifier extends Notifier<Branding> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'branding';

  @override
  Branding build() {
    _restore();

    return Branding.stock;
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null) {
        state = Branding.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {
      // A first launch, or a store the platform lacks: stock is already right.
    }

    await refresh();
  }

  /// Re-reads the server. Called on launch and after an admin saves the
  /// appearance or colours, so the app re-themes without a restart.
  Future<void> refresh() async {
    try {
      final fresh = await ref.read(repositoryProvider).branding();
      state = fresh;
      await _storage.write(key: _key, value: jsonEncode(fresh.toJson()));
    } catch (_) {
      // Offline, or a server that predates the endpoint: keep what we have.
    }
  }
}

final brandingProvider = NotifierProvider<BrandingNotifier, Branding>(BrandingNotifier.new);
