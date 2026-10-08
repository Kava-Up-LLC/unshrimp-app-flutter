import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/auth_exception.dart';

/// Calls the AppAmbit Cloud Code auth functions. Hashing and credential checks
/// happen server-side; this class only sends the input and parses the reply.
class AuthRepository {
  const AuthRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  /// Returns the session token issued by `auth_register`.
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _cloud.call('auth_register', {
      'name': name,
      'email': email,
      'password': password,
    }, errorFrom: _exceptionFrom);
    return _readToken(data);
  }

  /// Returns the session token issued by `auth_login`.
  Future<String> logIn({
    required String email,
    required String password,
  }) async {
    final data = await _cloud.call('auth_login', {
      'email': email,
      'password': password,
    }, errorFrom: _exceptionFrom);
    return _readToken(data);
  }

  /// Whether `auth_validate` accepts [token]. Idempotent read → may retry once.
  Future<bool> validate(String token) async {
    final data = await _cloud.call(
      'auth_validate',
      {'token': token},
      errorFrom: _exceptionFrom,
      retry: true,
    );
    return data['valid'] == true;
  }

  /// Builds an [AuthException] when the function replied with an error body,
  /// e.g. `{ "error": "INVALID_CREDENTIALS", "message": "..." }`.
  static AuthException? _exceptionFrom(Map<String, dynamic> data) {
    final code = data['error'] ?? data['code'];
    if (code == null) return null;
    return AuthException(
      code: code.toString(),
      message: (data['message'] ?? code).toString(),
    );
  }

  static String _readToken(Map<String, dynamic> data) {
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
