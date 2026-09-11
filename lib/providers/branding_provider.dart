import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/branding.dart';
import '../repositories/spendlog_repository.dart';

/// The look the admin chose, driving the theme. Restored from the last run
/// first so a cold start does not flash the stock look, then refreshed from
/// the server. Rides in the same store as the token, like the theme mode.
class BrandingNotifier extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _key = 'branding';

  Branding _state = Branding.stock;

  Branding get state => _state;

  SpendLogRepository? _repository;

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
    _state = next;
    notifyListeners();
  }
}
