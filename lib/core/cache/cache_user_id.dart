import 'dart:convert';

/// The cache user id for a session [token]: the JWT's `sub` claim.
///
/// This only partitions the cache by account; it is **not** a security check
/// (the signature is never verified here — Cloud Code authorizes every call).
/// An unparsable token falls back to a stable `'unknown'` id so a cache read
/// never throws on a malformed token.
String cacheUserIdFromToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return 'unknown';
    var seg = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    seg = seg.padRight((seg.length + 3) ~/ 4 * 4, '=');
    final decoded = jsonDecode(utf8.decode(base64.decode(seg)));
    final sub = decoded is Map ? decoded['sub'] : null;
    return sub == null ? 'unknown' : sub.toString();
  } catch (_) {
    return 'unknown';
  }
}
