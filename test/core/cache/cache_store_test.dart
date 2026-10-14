import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late CacheStore store;
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    store = CacheStore(prefs);
  });

  test('a write is read back as the same payload', () async {
    await store.write('u1', 'user_stats', {'streak': 3});
    final entry = await store.read('u1', 'user_stats');

    expect(entry, isNotNull);
    expect(entry!.payload, {'streak': 3});
  });

  test('one user never reads another user\'s entry', () async {
    await store.write('u1', 'user_stats', {'streak': 3});

    final other = await store.read('u2', 'user_stats');

    expect(other, isNull);
  });

  test('a bumped schema version discards the old payload without throwing', () async {
    // A value stored under a previous schema version's key shape.
    await prefs.setString(
      'cache.v0.u1.user_stats',
      jsonEncode({'at': DateTime.now().toIso8601String(), 'payload': {'streak': 9}}),
    );

    final entry = await store.read('u1', 'user_stats');

    expect(entry, isNull);
  });

  test('a malformed stored value is discarded, not thrown', () async {
    await prefs.setString('cache.${CacheStore.schemaVersion}.u1.user_stats', 'not json');

    final entry = await store.read('u1', 'user_stats');

    expect(entry, isNull);
  });

  test('clearUser removes only that user\'s entries', () async {
    await store.write('u1', 'user_stats', {'streak': 1});
    await store.write('u1', 'settings', {'interval': 30});
    await store.write('u2', 'user_stats', {'streak': 2});

    await store.clearUser('u1');

    expect(await store.read('u1', 'user_stats'), isNull);
    expect(await store.read('u1', 'settings'), isNull);
    expect((await store.read('u2', 'user_stats'))!.payload, {'streak': 2});
  });

  test('clearAll removes every cached entry', () async {
    await store.write('u1', 'user_stats', {'streak': 1});
    await store.write('u2', 'user_stats', {'streak': 2});

    await store.clearAll();

    expect(await store.read('u1', 'user_stats'), isNull);
    expect(await store.read('u2', 'user_stats'), isNull);
  });
}
