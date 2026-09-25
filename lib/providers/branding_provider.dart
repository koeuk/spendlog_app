import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../models/branding.dart';
import '../models/preferences.dart';
import '../repositories/spendlog_repository.dart';
import 'auth_provider.dart';

/// The look the admin chose, driving the theme. Restored from the last run
/// first so a cold start does not flash the stock look, then refreshed from
/// the server. Rides in the same store as the token, like the theme mode.
class BrandingNotifier extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _key = 'branding';

  Branding _state = Branding.stock;

  Branding get state => _state;

  SpendLogRepository? _repository;
  bool _disposed = false;

  /// Bound by the provider. Only the first binding starts the restore: unlike
  /// the data notifiers this one does not follow the language, since the marks
  /// and colours are the same in every one.
  void bind(SpendLogRepository repository) {
    final first = _repository == null;
    _repository = repository;

    if (first) _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved != null) {
        _set(Branding.fromJson(jsonDecode(saved) as Map<String, dynamic>));
      }
    } catch (_) {
      // A first launch, or a store the platform lacks: stock is already right.
    }

    await refresh();
  }

  /// Re-reads the server. Called on launch and after an admin saves the
  /// appearance or colours, so the app re-themes without a restart.
  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;

    try {
      final fresh = await repository.branding();
      _set(fresh);
      await _storage.write(key: _key, value: jsonEncode(fresh.toJson()));
    } catch (_) {
      // Offline, or a server that predates the endpoint: keep what we have.
    }
  }

  void _set(Branding next) {
    if (_disposed) return;

    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The look to paint with: the admin's branding, with the signed-in account's
/// own colours laid over it. Watches both, so saving a preference or signing
/// in as someone else re-themes at once.
Branding watchLook(BuildContext context) {
  final branding = context.watch<BrandingNotifier>().state;
  final own = context.select<AuthNotifier, UserPreferences>(
    (auth) => auth.state.user?.preferences ?? UserPreferences.none,
  );

  return branding.withOwn(own);
}
