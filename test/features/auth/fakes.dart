import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/models/auth_session.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token, this.expiresAt]);

  String? token;
  DateTime? expiresAt;

  @override
  Future<String?> read() async => token;

  @override
  Future<DateTime?> readExpiresAt() async => expiresAt;

  @override
  Future<void> writeSession(AuthSession session) async {
    token = session.token;
    expiresAt = session.expiresAt;
  }

  @override
  Future<void> delete() async {
    token = null;
    expiresAt = null;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.error,
    this.valid = true,
    this.validateError,
    this.refreshError,
  });

  final AuthException? error;
  final bool valid;

  /// Thrown by [validate] (e.g. a network failure or INVALID_TOKEN).
  final AuthException? validateError;

  /// Thrown by [refresh] only (so a failed refresh can be exercised separately).
  final AuthException? refreshError;

  int calls = 0;
  int validateCalls = 0;
  int refreshCalls = 0;

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls++;
    if (error != null) throw error!;
    return const AuthSession(token: 'register-token');
  }

  @override
  Future<AuthSession> logIn({
    required String email,
    required String password,
  }) async {
    calls++;
    if (error != null) throw error!;
    return const AuthSession(token: 'login-token');
  }

  @override
  Future<AuthSession> refresh(String token) async {
    refreshCalls++;
    if (refreshError != null) throw refreshError!;
    return AuthSession(
      token: 'refreshed-token',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  @override
  Future<bool> validate(String token) async {
    calls++;
    validateCalls++;
    if (validateError != null) throw validateError!;
    return valid;
  }
}
