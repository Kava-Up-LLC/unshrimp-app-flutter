import 'dart:convert';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unshrimp_app/core/cache/cache_store.dart';
import 'package:unshrimp_app/core/cache/cache_user_id.dart';
import 'package:unshrimp_app/core/cloud/cloud_functions.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

import '../../support/in_memory_prefs.dart';

String _token(int id) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'sub': id})}.sig';
}

CloudCodeResponse _ok(Map<String, dynamic> data) =>
    CloudCodeResponse(data: data, statusCode: 200, requestId: null, headers: const {});

/// Cloud that returns [data] on the one call it is given.
CloudFunctions _onlineCloud(Map<String, dynamic> data) =>
    CloudFunctions(invoke: (_, _, _) async => _ok(data), retryDelay: Duration.zero);

/// Cloud that fails like an offline device: a transport CloudCodeError.
CloudFunctions _offlineCloud() => CloudFunctions(
  invoke: (_, _, _) => throw const CloudCodeError(
    code: CloudCodeErrorCode.networkUnavailable,
    message: 'offline',
  ),
  retryDelay: Duration.zero,
);

const _proPayload = {
  'is_pro': true,
  'entitlement': 'pro_trial',
  'trial_ends_at': '2026-11-03T12:00:00.000Z',
  'pro_until': null,
};
const _freePayload = {'is_pro': false, 'entitlement': 'free'};

void main() {
  late CacheStore cache;
  final token = _token(42);
  final userId = cacheUserIdFromToken(token);

  setUp(() {
    useInMemoryPrefs();
    cache = CacheStore(SharedPreferencesAsync());
  });

  test('a fresh online read is trusted as-is', () async {
    final repo = EntitlementRepository(cloud: _onlineCloud(_proPayload), cache: cache);
    final ent = await repo.fetch(token);
    expect(ent.isPro, isTrue);
    expect(ent.entitlement, 'pro_trial');
  });

  test('offline within the grace window keeps a Pro user Pro', () async {
    await cache.write(userId, 'entitlement', _proPayload);
    final writeTime = DateTime.now();
    final repo = EntitlementRepository(
      cloud: _offlineCloud(),
      cache: cache,
      graceDays: () async => 7,
      now: () => writeTime.add(const Duration(days: 3)),
    );

    final ent = await repo.fetch(token);
    expect(ent.isPro, isTrue);
  });

  test('offline past the grace window falls back to Free', () async {
    await cache.write(userId, 'entitlement', _proPayload);
    final writeTime = DateTime.now();
    final repo = EntitlementRepository(
      cloud: _offlineCloud(),
      cache: cache,
      graceDays: () async => 7,
      now: () => writeTime.add(const Duration(days: 10)),
    );

    final ent = await repo.fetch(token);
    expect(ent.isPro, isFalse);
    expect(ent.entitlement, 'free');
  });

  test('offline, a cached Free value never becomes Pro', () async {
    await cache.write(userId, 'entitlement', _freePayload);
    final repo = EntitlementRepository(
      cloud: _offlineCloud(),
      cache: cache,
      graceDays: () async => 7,
    );

    final ent = await repo.fetch(token);
    expect(ent.isPro, isFalse);
  });

  test('refresh bypasses the cache and overwrites it with the fresh value', () async {
    await cache.write(userId, 'entitlement', _freePayload);
    final repo = EntitlementRepository(cloud: _onlineCloud(_proPayload), cache: cache);

    final ent = await repo.refresh(token);
    expect(ent.isPro, isTrue);

    final cached = await cache.read(userId, 'entitlement');
    expect(cached!.payload['is_pro'], isTrue); // cache updated for the pill/locks
  });
}
