import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../api/api_client.dart';
import '../models/user.dart';

/// Every auth call in one place, mirroring the API doc: login issues a bearer
/// token named after this device, and the OTP endpoints drive password resets.
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<User> login(String email, String password) async {
    final response = await _client.dio.post('/login', data: {
      'email': email,
      'password': password,
      // Names the token in the user's token list so it can be revoked
      // individually later. kIsWeb first: dart-io Platform checks throw on web.
      'device_name': kIsWeb
          ? 'Web app'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'iOS app'
              : 'Android app',
    });

    final data = response.data as Map<String, dynamic>;
    await _client.saveToken(data['token'] as String);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async {
    final response = await _client.dio.get('/me');

    return User.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/logout');
    } finally {
      // The local token goes regardless — a dead server must not trap the
      // user in a session they asked to leave.
      await _client.clearToken();
    }
  }

  Future<void> requestResetCode(String email) async {
    await _client.dio.post('/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.dio.post('/reset-password', data: {
      'email': email,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }
}
