import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../api/api_client.dart';
import '../models/user.dart';

/// Every auth call in one place, mirroring the API doc: login issues a bearer
/// token named after this device, and the OTP endpoints drive password resets.
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  /// Names the token in the user's token list so it can be revoked
  /// individually later. kIsWeb first: dart-io Platform checks throw on web.
  static String get _deviceName => kIsWeb
      ? 'Web app'
      : defaultTargetPlatform == TargetPlatform.iOS
          ? 'iOS app'
          : 'Android app';

  Future<User> login(String email, String password) async {
    final response = await _client.dio.post('/login', data: {
      'email': email,
      'password': password,
      'device_name': _deviceName,
    });

    final data = response.data as Map<String, dynamic>;
    await _client.saveToken(data['token'] as String);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Creates the account and signs straight in — the server returns a token
  /// with the response, the same shape as [login], so there is no second
  /// round-trip. The new user always gets the plain `user` role server-side.
  Future<User> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.dio.post('/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': _deviceName,
    });

    final data = response.data as Map<String, dynamic>;
    await _client.saveToken(data['token'] as String);

    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> me() async {
    final response = await _client.dio.get('/me');

    return User.fromJson((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
  }

  /// Never throws. Revoking the token server-side is best effort: the local
  /// token goes regardless, because a dead server must not trap the user in a
  /// session they asked to leave. A token we failed to revoke is left to
  /// expire on its own rather than blocking the sign-out.
  Future<void> logout() async {
    try {
      await _client.dio.post('/logout');
    } catch (_) {
      // Offline, or the token was already revoked elsewhere. Either way the
      // only thing left to do is forget it locally.
    }

    await _client.clearToken();
  }

  /// Confirms the signed-in account's email with the 6-digit code the server
  /// mailed at sign-up (or on a resend). Returns the server's message and the
  /// user, now carrying `email_verified_at`. A wrong, expired or out-of-guesses
  /// code is a 422 on `code`.
  Future<({String message, User user})> verifyEmail(String code) async {
    final response = await _client.dio.post('/email/verify', data: {
      'code': code,
    });

    final data = response.data as Map<String, dynamic>;

    return (
      message: data['message'] as String? ?? '',
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  /// Mails a fresh verification code. Asked again within a minute it is a 422
  /// on `code`; returns the server's message otherwise.
  Future<String> resendVerificationCode() async {
    final response = await _client.dio.post('/email/verification-notification');

    return (response.data as Map<String, dynamic>)['message'] as String? ?? '';
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
