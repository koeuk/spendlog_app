/// Where the SpendLog API lives.
///
/// Pick with a compile-time flag, defaulting to the Android emulator's alias
/// for the machine running `php artisan serve`:
///
///   flutter run                                        // emulator
///   flutter run --dart-define=API=lan                  // real phone, same Wi-Fi
///   flutter run --dart-define=API=prod                 // the deployed server
class Env {
  static const _selected = String.fromEnvironment('API', defaultValue: 'emulator');

  /// 10.0.2.2 is how the Android emulator reaches the host machine's
  /// localhost. iOS simulators can use 127.0.0.1 directly.
  static const _urls = {
    'emulator': 'http://10.0.2.2:8000/api/v1',
    'lan': 'http://192.168.1.100:8000/api/v1', // adjust to your PC's LAN IP
    'prod': 'https://spendlog.example.com/api/v1', // adjust once deployed
  };

  static String get baseUrl => _urls[_selected] ?? _urls['emulator']!;
}
