import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_store.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late CachedRead<int> cached;
  late CacheStore store;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    store = CacheStore(SharedPreferencesAsync());
    cached = CachedRead<int>(
      store: store,
      decode: (payload) => (payload['streak'] as num).toInt(),
    );
  });

  Future<CacheResult<int>> read(Future<Map<String, dynamic>> Function() fetch) =>
      cached.read(userId: 'u1', slot: 'user_stats', fetch: fetch);

  test('a successful read stores the payload and reports online', () async {
    final result = await read(() async => {'streak': 5});

    expect(result.value, 5);
    expect(result.offline, isFalse);
    expect((await store.read('u1', 'user_stats'))!.payload, {'streak': 5});
  });

  test('a transport failure returns the cached payload and marks offline', () async {
    await store.write('u1', 'user_stats', {'streak': 7});

    final result = await read(() async {
      throw const AuthException(code: 'timedOut', message: "Couldn't reach the cloud.");
    });

    expect(result.value, 7);
    expect(result.offline, isTrue);
    expect(result.asOf, isNotNull);
  });

  test('a function-level error still throws instead of serving the cache', () async {
    await store.write('u1', 'user_stats', {'streak': 7});

    expect(
      () => read(() async {
        throw const AuthException(code: 'INVALID_TOKEN', message: 'Session expired.');
      }),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'INVALID_TOKEN')),
    );
  });

  test('a transport failure with nothing cached rethrows', () async {
    expect(
      () => read(() async {
        throw const AuthException(code: 'networkUnavailable', message: 'Offline.');
      }),
      throwsA(isA<AuthException>()),
    );
  });

  // iOS can surface an offline failure as a non-AuthException, not the mapped
  // AuthException(networkUnavailable) Android throws. Each must still serve cache.
  for (final entry in {
    'PlatformException': () => throw PlatformException(code: 'unavailable'),
    'SocketException': () => throw const SocketException('Network is unreachable'),
    'TimeoutException': () => throw TimeoutException('timed out'),
  }.entries) {
    test('a ${entry.key} serves the cached payload (iOS-shaped offline)', () async {
      await store.write('u1', 'user_stats', {'streak': 11});

      final result = await read(() async => entry.value());

      expect(result.offline, isTrue);
      expect(result.value, 11);
    });
  }

  test('a non-AuthException with nothing cached still rethrows', () async {
    expect(
      () => read(() async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
  });

  test('a cache write failure still returns the fresh fetched value', () async {
    final failing = CachedRead<int>(
      store: _ThrowOnWriteStore(SharedPreferencesAsync()),
      decode: (p) => (p['streak'] as num).toInt(),
    );

    final result = await failing.read(
      userId: 'u1',
      slot: 'user_stats',
      fetch: () async => {'streak': 3},
    );

    expect(result.offline, isFalse);
    expect(result.value, 3);
  });

  test('one user never reads another user\'s cached payload', () async {
    await store.write('u1', 'user_stats', {'streak': 7});

    expect(
      () => cached.read(
        userId: 'u2',
        slot: 'user_stats',
        fetch: () async {
          throw const AuthException(code: 'timedOut', message: 'Offline.');
        },
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('every CloudCode transport code is recognised, server codes are not', () {
    expect(isTransportError('timedOut'), isTrue);
    expect(isTransportError('networkUnavailable'), isTrue);
    expect(isTransportError('http'), isTrue);
    expect(isTransportError('transport'), isTrue);
    expect(isTransportError('UNEXPECTED_RESPONSE'), isTrue);
    expect(isTransportError('INVALID_TOKEN'), isFalse);
    expect(isTransportError('NO_SETTINGS'), isFalse);
  });
}

/// A [CacheStore] whose write always fails, to prove a write error never breaks
/// an otherwise successful read.
class _ThrowOnWriteStore extends CacheStore {
  _ThrowOnWriteStore(super.prefs);

  @override
  Future<void> write(String userId, String slot, Map<String, dynamic> payload) async =>
      throw StateError('write failed');
}
