import 'package:move_well_app/features/auth/models/auth_exception.dart';
import 'package:move_well_app/features/auth/repositories/auth_repository.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.error, this.valid = true});

  final AuthException? error;
  final bool valid;
  int calls = 0;

  @override
  Future<String> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls++;
    if (error != null) throw error!;
    return 'register-token';
  }

  @override
  Future<String> logIn({
    required String email,
    required String password,
  }) async {
    calls++;
    if (error != null) throw error!;
    return 'login-token';
  }

  @override
  Future<bool> validate(String token) async {
    calls++;
    return valid;
  }
}
