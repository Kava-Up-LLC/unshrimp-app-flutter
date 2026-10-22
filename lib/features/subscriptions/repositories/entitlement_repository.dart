import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cache_user_id.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/entitlement_policy.dart';
import '../../../core/cloud/cloud_functions.dart';
import '../models/entitlement.dart';

/// Reads the logged-in user's entitlement through `get_entitlements`, behind
/// the reserved per-user entitlement cache slot.
///
/// A fresh read is trusted as-is. Offline (a transport failure served from the
/// cache), a Pro value is honoured only while the cached payload is still
/// within the Remote-Config grace window ([entitlementGraceDays]); past that,
/// or for a cached Free value, it reads as Free. So a Pro user with no network
/// stays Pro for the grace period and no longer.
class EntitlementRepository {
  EntitlementRepository({
    CloudFunctions cloud = const CloudFunctions(),
    required CacheStore cache,
    Future<int> Function()? graceDays,
    DateTime Function()? now,
  }) : _cloud = cloud,
       _cache = cache,
       _graceDays = graceDays ?? entitlementGraceDays,
       _now = now ?? DateTime.now;

  static const _slot = entitlementSlot;

  final CloudFunctions _cloud;
  final CacheStore _cache;
  final Future<int> Function() _graceDays;
  final DateTime Function() _now;

  /// `get_entitlements`, cached per user. Idempotent read → may retry once. On a
  /// transport failure the stored value is returned under the grace rule; a
  /// function-level error (INVALID_TOKEN) still throws so the session can end.
  Future<Entitlement> fetch(String token) async {
    final result = await CachedRead<Entitlement>(
      store: _cache,
      decode: Entitlement.fromJson,
    ).read(
      userId: cacheUserIdFromToken(token),
      slot: _slot,
      fetch: () =>
          _cloud.call('get_entitlements', {'token': token}, retry: true),
    );
    if (!result.offline) return result.value;
    return _underGrace(result);
  }

  /// Re-reads `get_entitlements` straight from the cloud, **bypassing** the
  /// cache, then refreshes the cache. Used after a purchase so the pill and the
  /// locks follow what the cloud says at once.
  Future<Entitlement> refresh(String token) async {
    final payload = await _cloud.call(
      'get_entitlements',
      {'token': token},
      retry: true,
    );
    try {
      await _cache.write(cacheUserIdFromToken(token), _slot, payload);
    } catch (_) {
      // A cache write failure must not break a good read.
    }
    return Entitlement.fromJson(payload);
  }

  Future<Entitlement> _underGrace(CacheResult<Entitlement> result) async {
    // A cached Free value never becomes Pro offline.
    if (!result.value.isPro) return result.value;
    final asOf = result.asOf;
    final grace = await _graceDays();
    if (asOf != null && _now().difference(asOf) <= Duration(days: grace)) {
      return result.value; // within grace: a Pro user with no network stays Pro
    }
    return Entitlement.free; // past grace offline: fall back to Free
  }
}

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) => EntitlementRepository(cache: ref.read(cacheStoreProvider)),
);
