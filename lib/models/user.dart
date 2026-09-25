import 'preferences.dart';

class User {
  const User({
    required this.uuid,
    required this.name,
    required this.email,
    required this.isAdmin,
    this.username,
    this.phone,
    this.avatarUrl,
    this.preferences = UserPreferences.none,
  });

  final String uuid;
  final String name;
  final String email;
  final bool isAdmin;
  final String? username;

  /// A contact number, or null when none was given.
  final String? phone;

  /// Absolute, cache-busted by the server; null when there is no photo.
  final String? avatarUrl;

  /// The account's own currency and colours; see [UserPreferences].
  final UserPreferences preferences;

  User copyWith({UserPreferences? preferences}) => User(
    uuid: uuid,
    name: name,
    email: email,
    isAdmin: isAdmin,
    username: username,
    phone: phone,
    avatarUrl: avatarUrl,
    preferences: preferences ?? this.preferences,
  );

  factory User.fromJson(Map<String, dynamic> json) => User(
    uuid: json['uuid'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    isAdmin: json['is_admin'] as bool? ?? false,
    username: json['username'] as String?,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    preferences: UserPreferences.fromJson(
      json['preferences'] as Map<String, dynamic>?,
    ),
  );
}
