/// A session issued by `auth_login` / `auth_register` / `auth_refresh`: the
/// signed [token] and, when the server sent it, its [expiresAt].
///
/// [expiresAt] is a client convenience only — it decides whether to open the
/// app or the Log In screen offline. It is **not** a security boundary: the
/// device cannot verify the token's signature, so every data call is still
/// authorized by Cloud Code, which checks the signed expiry itself.
class AuthSession {
  const AuthSession({required this.token, this.expiresAt});

  final String token;
  final DateTime? expiresAt;
}
