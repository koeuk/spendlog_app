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

  /// The port `php artisan serve` is on. Worth a knob rather than a constant:
  /// this machine runs more than one Laravel app, and pointing at the wrong one
  /// fails as a *login error* ("Please sign in through the admin panel") rather
  /// than a connection error — which reads like a bad password.
  ///
  ///   flutter run -d chrome --dart-define=PORT=8000
  static const _port = String.fromEnvironment('PORT', defaultValue: '8002');

  static const _host = '127.0.0.1';

  /// How the Android emulator reaches the host machine's localhost. iOS
  /// simulators can use 127.0.0.1 directly.
  static const _emulatorHost = '10.0.2.2';

  static const _urls = {
    'lan': 'http://192.168.1.100:$_port/api/v1', // adjust to your PC's LAN IP
    'prod': 'https://spendlog.example.com/api/v1', // adjust once deployed
  };

  static String get baseUrl =>
      _urls[_selected] ?? 'http://${kIsWeb ? _host : _emulatorHost}:$_port/api/v1';
}
