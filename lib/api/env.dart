import 'package:flutter/foundation.dart' show kIsWeb;

/// Where the SpendLog API lives.
///
/// Pick with a compile-time flag; the default adapts to where the app runs —
/// Chrome talks straight to localhost, the Android emulator goes through its
/// 10.0.2.2 alias for the host machine:
///
///   flutter run                                        // emulator / Chrome
///   flutter run --dart-define=API=lan                  // real phone, same Wi-Fi
///   flutter run --dart-define=API=prod                 // the deployed server
class Env {
  static const _selected = String.fromEnvironment('API', defaultValue: 'auto');

  static const _urls = {
    'lan': 'http://192.168.1.100:8000/api/v1', // adjust to your PC's LAN IP
    'prod': 'https://spendlog.example.com/api/v1', // adjust once deployed
  };

  static String get baseUrl =>
      _urls[_selected] ??
      (kIsWeb
          ? 'http://127.0.0.1:8000/api/v1'
          : 'http://10.0.2.2:8000/api/v1');
}
