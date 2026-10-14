import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/auth_exception.dart';
import '../models/auth_session.dart';

/// Calls the AppAmbit Cloud Code auth functions. Hashing and credential checks
/// happen server-side; this class only sends the input and parses the reply.
class AuthRepository {
  const AuthRepository([this._cloud = const CloudFunctions()]);

  final CloudFunctions _cloud;

  /// Returns the session issued by `auth_register`.
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _cloud.call('auth_register', {
      'name': name,
      'email': email,
      'password': password,
    }, errorFrom: _exceptionFrom);
    return _readSession(data);
  }

  /// Returns the session issued by `auth_login`.
  Future<AuthSession> logIn({
    required String email,
    required String password,
  }) async {
    final data = await _cloud.call('auth_login', {
      'email': email,
      'password': password,
    }, errorFrom: _exceptionFrom);
    return _readSession(data);
  }

  /// Exchanges a still-valid [token] for a fresh one via `auth_refresh`. A
  /// function-level INVALID_TOKEN surfaces as an [AuthException]; a transport
  /// failure does too. The caller only swaps the stored pair on success, so a
  /// failure keeps the old token in place. Not retried: re-issuing is cheap but
  /// a timed-out call may already have committed, and a double refresh is waste.
  Future<AuthSession> refresh(String token) async {
    final data = await _cloud.call('auth_refresh', {
      'token': token,
    }, errorFrom: _exceptionFrom);
    return _readSession(data);
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

  static AuthSession _readSession(Map<String, dynamic> data) {
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthException(
        code: 'UNEXPECTED_RESPONSE',
        message: 'The session could not be started. Please try again.',
      );
    }
    final rawExpiry = data['expires_at'];
    return AuthSession(
      token: token,
      expiresAt: rawExpiry is String ? DateTime.tryParse(rawExpiry) : null,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);
