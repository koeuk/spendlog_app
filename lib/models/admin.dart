/// The admin desk's shapes: user rows, FAQ entries, spending settings.
class AdminUser {
  const AdminUser({
    required this.uuid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.username,
    this.avatarUrl,
  });

  final String uuid;
  final String name;
  final String? username;
  final String email;
  final String role;
  final String status;

  /// Absolute, cache-busted by the server; null when there is no photo.
  final String? avatarUrl;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        username: json['username'] as String?,
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        status: json['status'] as String? ?? 'active',
        avatarUrl: json['avatar_url'] as String?,
      );
}

class FaqEntry {
  const FaqEntry({
    required this.uuid,
    required this.question,
    required this.answer,
    required this.status,
  });

  final String uuid;
  final String question;
  final String answer;
  final String status;

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        uuid: json['uuid'] as String,
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
      );
}

class SpendingSettings {
  const SpendingSettings({
    required this.khrPerUsd,
    required this.defaultCurrency,
    required this.guidanceEnabled,
    required this.warning,
    required this.advice,
  });

  final double khrPerUsd;
  final String defaultCurrency;
  final bool guidanceEnabled;
  final String warning;
  final String advice;

  factory SpendingSettings.fromJson(Map<String, dynamic> json) => SpendingSettings(
        khrPerUsd: (json['khr_per_usd'] as num?)?.toDouble() ?? 4100,
        defaultCurrency: json['default_currency'] as String? ?? 'USD',
        guidanceEnabled: json['spending_guidance_enabled'] as bool? ?? false,
        warning: json['spending_warning'] as String? ?? '',
        advice: json['spending_advice'] as String? ?? '',
      );
}

/// GET /admin/settings/branding — the name and marks shown across the app.
class BrandingSettings {
  const BrandingSettings({
    required this.appName,
    this.copyrightHolder,
    this.logoUrl,
    this.faviconUrl,
  });

  final String appName;
  final String? copyrightHolder;
  final String? logoUrl;
  final String? faviconUrl;

  factory BrandingSettings.fromJson(Map<String, dynamic> json) => BrandingSettings(
        appName: json['app_name'] as String? ?? '',
        copyrightHolder: json['copyright_holder'] as String?,
        logoUrl: json['logo'] as String?,
        faviconUrl: json['favicon'] as String?,
      );
}

/// One swatch the server offers — the same list the web page draws.
class ColorPreset {
  const ColorPreset({required this.value, required this.label, this.isDefault = false});

  /// '#rrggbb'
  final String value;
  final String label;
  final bool isDefault;

  factory ColorPreset.fromJson(Map<String, dynamic> json) => ColorPreset(
        value: json['value'] as String? ?? '',
        label: json['label'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
      );
}

/// GET /admin/settings/colors — the palette plus its presets.
class ColorSettings {
  const ColorSettings({
    required this.buttonColor,
    required this.bodyColor,
    required this.buttonPresets,
    required this.bodyPresets,
  });

  final String buttonColor;
  final String bodyColor;
  final List<ColorPreset> buttonPresets;
  final List<ColorPreset> bodyPresets;

  factory ColorSettings.fromJson(Map<String, dynamic> json) => ColorSettings(
        buttonColor: json['button_color'] as String? ?? '#171717',
        bodyColor: json['body_color'] as String? ?? '#ffffff',
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
