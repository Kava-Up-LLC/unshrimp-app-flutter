/// Failure returned by an AppAmbit auth function (e.g. `INVALID_CREDENTIALS`)
/// or by the transport layer.
class AuthException implements Exception {
  const AuthException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
