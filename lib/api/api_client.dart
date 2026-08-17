import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'env.dart';

/// One Dio for the whole app: bearer token attached when present, JSON in and
/// out, and a small surface (`get`/`post`/...) so screens never import Dio.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'api_token';

  /// Endpoints reachable without a token. A `401` from one of these says
  /// nothing about a stored session, so it must not sign anyone out.
  static const _publicPaths = {
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
  };

  final _unauthorized = StreamController<void>.broadcast();

  /// Fires when the server rejects the stored token — revoked from the web's
  /// token list, or expired. `AuthNotifier` listens and drops the session, so
  /// the router returns the user to login instead of leaving every screen
  /// stuck on "Unauthenticated."
  ///
  /// Only `401` counts. Per the API doc a bad password is a `422` and a
  /// missing token ability is a `403` — neither means the session is dead.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !_publicPaths.contains(error.requestOptions.path)) {
            await clearToken();
            _unauthorized.add(null);
          }

          // The caller still sees the failure and shows its own message.
          handler.next(error);
        },
      ),
    );

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

/// The first human-readable message out of a Laravel error payload —
/// validation errors first, then the top-level message, then a fallback.
String apiErrorMessage(Object error, {String fallback = 'Something went wrong.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check your connection.';
    }
  }
  return fallback;
}
