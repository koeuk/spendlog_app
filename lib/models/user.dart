class User {
  const User({
    required this.uuid,
    required this.name,
    required this.email,
    required this.isAdmin,
    this.username,
  });

  final String uuid;
  final String name;
  final String email;
  final bool isAdmin;
  final String? username;

  factory User.fromJson(Map<String, dynamic> json) => User(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        username: json['username'] as String?,
      );
}
