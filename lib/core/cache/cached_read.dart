import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';

import '../../features/auth/models/auth_exception.dart';
import 'cache_store.dart';

/// The outcome of a [CachedRead]: the decoded [value], whether it was served
/// from the cache because the network was unreachable ([offline]), and, when
/// offline, when that cached payload was stored ([asOf]). [asOf] is null for a
/// fresh value straight from Cloud Code.
class CacheResult<T> {
  const CacheResult({required this.value, required this.offline, this.asOf});

  final T value;
  final bool offline;
  final DateTime? asOf;
}

/// Reads one Cloud Code payload with an offline fallback.
///
/// On success the raw payload is cached and returned ([offline] false). On a
/// **transport** failure the last stored payload is returned ([offline] true),
/// or the error rethrows when nothing is cached.
///
/// A function-level answer from AppAmbit — `INVALID_TOKEN`, `NO_SETTINGS`, … —
/// is **always** an [AuthException] whose code is not a transport code; those
/// rethrow so the session can end, and are never served from stale cache.
/// Everything else is treated as transport and serves the cache: a
/// transport-coded [AuthException] (what Android throws offline), **and any
/// other exception type** — a `PlatformException`, `SocketException`,
/// `TimeoutException`, etc. — which is how an offline failure can surface on
/// iOS. This is classified by type/code, never by message text, so the copy of
/// an error never decides whether the session ends.
class CachedRead<T> {
  const CachedRead({required this.store, required this.decode});

  final CacheStore store;
  final T Function(Map<String, dynamic> payload) decode;

  Future<CacheResult<T>> read({
    required String userId,
    required String slot,
    required Future<Map<String, dynamic>> Function() fetch,
  }) async {
    final Map<String, dynamic> payload;
    try {
      payload = await fetch();
    } catch (error) {
      // A function-level answer ends the session; everything else is transport.
      if (error is AuthException && !isTransportError(error.code)) rethrow;
      final cached = await store.read(userId, slot);
      if (cached == null) rethrow;
      return CacheResult(
        value: decode(cached.payload),
        offline: true,
        asOf: cached.asOf,
      );
    }

    // Fetch succeeded. A cache write failure must not break a good read.
    try {
      await store.write(userId, slot, payload);
    } catch (_) {}
    return CacheResult(value: decode(payload), offline: false);
  }
}

final _transportCodes = <String>{
  for (final code in CloudCodeErrorCode.values) code.name,
  'UNEXPECTED_RESPONSE',
};

/// Whether [code] came from the transport layer (couldn't reach AppAmbit or
/// couldn't read a reply) rather than a function-level answer. Transport codes
/// are the [CloudCodeErrorCode] names plus `UNEXPECTED_RESPONSE`; function-level
/// codes are the server's own upper-snake codes (`INVALID_TOKEN`, …).
bool isTransportError(String code) => _transportCodes.contains(code);
