import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_exception.dart';

/// Calls the AppAmbit Cloud Code auth functions. Hashing and credential checks
/// happen server-side; this class only sends the input and parses the reply.
class AuthRepository {
  const AuthRepository();

  static const _timeout = Duration(seconds: 20);

  /// Returns the session token issued by `auth_register`.
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _call('auth_register', {
      'name': name,
      'email': email,
      'password': password,
    });
    return _readToken(data);
  }

  /// Returns the session token issued by `auth_login`.
  Future<String> logIn({
    required String email,
    required String password,
  }) async {
    final data = await _call('auth_login', {
      'email': email,
      'password': password,
    });
    return _readToken(data);
  }

  /// Whether `auth_validate` accepts [token].
  Future<bool> validate(String token) async {
    final data = await _call('auth_validate', {'token': token});
    return data['valid'] == true;
  }

  Future<Map<String, dynamic>> _call(
    String function,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await CloudCode.call(
        function,
        body: body,
        timeout: _timeout,
      ).future;
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AuthException(
          code: 'UNEXPECTED_RESPONSE',
          message: 'Unexpected response from the server.',
        );
      }
      final error = _exceptionFrom(data);
      if (error != null) throw error;
      return data;
    } on CloudCodeError catch (e) {
      final body = e.body;
      final error = body is Map<String, dynamic> ? _exceptionFrom(body) : null;
      throw error ??
          AuthException(
            code: e.code.name,
            message: e.code == CloudCodeErrorCode.http
                ? 'Something went wrong. Please try again.'
                : "Couldn't reach the server. Check your connection and try again.",
          );
    }
  }

  /// Builds an [AuthException] when the function replied with an error body,
  /// e.g. `{ "error": "INVALID_CREDENTIALS", "message": "..." }`.
  AuthException? _exceptionFrom(Map<String, dynamic> data) {
    final code = data['error'] ?? data['code'];
    if (code == null) return null;
    return AuthException(
      code: code.toString(),
      message: (data['message'] ?? code).toString(),
    );
  }

  String _readToken(Map<String, dynamic> data) {
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(
        code: 'UNEXPECTED_RESPONSE',
        message: 'The server did not return a session token.',
      );
    }
    return token;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);
