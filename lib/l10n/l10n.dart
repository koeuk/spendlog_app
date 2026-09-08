import 'dart:convert';

import 'package:flutter/services.dart';

/// The app's strings, the way the web does it: English is the key, Khmer is
/// looked up in a dictionary seeded from the web's lang/km.json plus the
/// app's own lines. An unknown key returns itself, so a missing translation
/// leaves the UI readable rather than blank.
abstract final class L10n {
  static const supported = ['en', 'km'];

  /// The active language code. Set by the locale notifier; every screen is
  /// rebuilt on a change, so reading it at build time is enough.
  static String locale = 'en';

  static Map<String, String> _km = const {};

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/lang/km.json');
      _km = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      // A build that predates the asset (a hot restart after pubspec changed)
      // or a corrupt file: English keys are still readable, so start anyway.
      _km = const {};
    }
  }

  static String tr(String key) => locale == 'km' ? (_km[key] ?? key) : key;

  static String label(String code) => code == 'km' ? 'ខ្មែរ' : 'English';
}

/// Shorthand for [L10n.tr], used at every visible string.
String tr(String key) => L10n.tr(key);
