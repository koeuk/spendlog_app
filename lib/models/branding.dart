import 'dart:ui';

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

  /// '#rrggbb' → Color, or null for anything else.
  static Color? parseHex(String hex) {
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex.trim());
    if (match == null) return null;

    return Color(int.parse('ff${match.group(1)!}', radix: 16));
  }
}
