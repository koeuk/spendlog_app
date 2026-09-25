import 'admin.dart';

/// One account's own currency and colours, each null where it follows the
/// app-wide value the admin set. Carried on /me, so the theme has it from the
/// first frame after sign-in.
class UserPreferences {
  const UserPreferences({this.currency, this.buttonColor, this.bodyColor});

  static const none = UserPreferences();

  /// 'USD' or 'KHR'.
  final String? currency;

  /// '#rrggbb'.
  final String? buttonColor;

  /// '#rrggbb', one of the body presets.
  final String? bodyColor;

  bool get hasOwnColours => buttonColor != null || bodyColor != null;

  factory UserPreferences.fromJson(Map<String, dynamic>? json) =>
      json == null
          ? none
          : UserPreferences(
              currency: json['currency'] as String?,
              buttonColor: json['button_color'] as String?,
              bodyColor: json['body_color'] as String?,
            );

  // Compared by value: the theme selects this off the user, and a fresh but
  // identical copy from /me must not rebuild the whole app.
  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.currency == currency &&
      other.buttonColor == buttonColor &&
      other.bodyColor == bodyColor;

  @override
  int get hashCode => Object.hash(currency, buttonColor, bodyColor);
}

/// GET /preferences — the account's own choices, the currency its amount
/// fields actually start on, and the swatches to offer.
class Preferences {
  const Preferences({
    required this.own,
    required this.defaultCurrency,
    required this.buttonPresets,
    required this.bodyPresets,
  });

  final UserPreferences own;
  final String defaultCurrency;
  final List<ColorPreset> buttonPresets;
  final List<ColorPreset> bodyPresets;

  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
        own: UserPreferences.fromJson(json),
        defaultCurrency: json['default_currency'] as String? ?? 'USD',
        buttonPresets: [
          for (final p in json['button_presets'] as List<dynamic>? ?? const [])
            ColorPreset.fromJson(p as Map<String, dynamic>),
        ],
        bodyPresets: [
          for (final p in json['body_presets'] as List<dynamic>? ?? const [])
            ColorPreset.fromJson(p as Map<String, dynamic>),
        ],
      );
}
