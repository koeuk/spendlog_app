/// The admin desk's shapes: user rows, FAQ entries, spending settings.
class AdminUser {
  const AdminUser({
    required this.uuid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.username,
  });

  final String uuid;
  final String name;
  final String? username;
  final String email;
  final String role;
  final String status;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        username: json['username'] as String?,
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        status: json['status'] as String? ?? 'active',
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
