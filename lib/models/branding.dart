import 'dart:ui';

import 'preferences.dart';

/// GET /branding — what the app looks like, as the admin set it on the web.
/// Read before sign-in and cached, so the first screen already wears it.
class Branding {
  const Branding({
    required this.name,
    this.logoUrl,
    required this.buttonColor,
    required this.branded,
    required this.bodyColor,
    required this.plainBackground,
  });

  /// What the app wears until the server says otherwise.
  static const stock = Branding(
    name: 'SpendLog',
    buttonColor: '#171717',
    branded: false,
    bodyColor: '#ffffff',
    plainBackground: false,
  );

  final String name;
  final String? logoUrl;

  /// '#rrggbb'. Only meaningful when [branded]: at the stock colour the app
  /// keeps its own green accent, the way the web keeps its stock tokens.
  final String buttonColor;
  final bool branded;

  /// '#rrggbb'. Painted flat as the page ground when [plainBackground]; White
  /// (the one exception) means the app's own default ground.
  final String bodyColor;
  final bool plainBackground;

  factory Branding.fromJson(Map<String, dynamic> json) => Branding(
        name: json['name'] as String? ?? stock.name,
        logoUrl: json['logo'] as String?,
        buttonColor: json['button_color'] as String? ?? stock.buttonColor,
        branded: json['branded'] as bool? ?? false,
        bodyColor: json['body_color'] as String? ?? stock.bodyColor,
        plainBackground: json['plain_background'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'logo': logoUrl,
        'button_color': buttonColor,
        'branded': branded,
        'body_color': bodyColor,
        'plain_background': plainBackground,
      };

  /// This look with one account's own colours laid over it, field by field.
  /// A chosen button is always "branded"; a chosen White background means the
  /// app's own ground, the way it does for the admin's choice.
  Branding withOwn(UserPreferences own) {
    final button = own.buttonColor != null && parseHex(own.buttonColor!) != null
        ? own.buttonColor
        : null;
    final body = own.bodyColor != null && parseHex(own.bodyColor!) != null
        ? own.bodyColor
        : null;
    if (button == null && body == null) return this;

    return Branding(
      name: name,
      logoUrl: logoUrl,
      buttonColor: button ?? buttonColor,
      branded: button != null || branded,
      bodyColor: body ?? bodyColor,
      plainBackground:
          body != null ? body.toLowerCase() != '#ffffff' : plainBackground,
    );
  }

  /// '#rrggbb' → Color, or null for anything else.
  static Color? parseHex(String hex) {
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex.trim());
    if (match == null) return null;

    return Color(int.parse('ff${match.group(1)!}', radix: 16));
  }
}
