import 'dart:convert';

import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_store.dart';
import 'package:unshrimp_app/core/cache/cache_user_id.dart';
import 'package:unshrimp_app/core/cloud/cloud_functions.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/settings/repositories/settings_repository.dart';
import 'package:unshrimp_app/features/settings/view_models/settings_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_prefs.dart';
import '../auth/fakes.dart';

/// A JWT whose `sub` claim is [id], so the real cache user id is deterministic.
String _token(int id) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'sub': id})}.sig';
}

const _settingsPayload = {
  'active_start': '09:00',
  'active_end': '18:00',
  'reminder_interval_min': 45,
  'grace_window_min': 60,
  'daily_goal': 5,
  'tone': 'direct',
  'pain_zone': 'neck',
  'quiet_mode': false,
  'paused_until': null,
};

/// Cloud that fails the way an offline device does: a transport-level
/// CloudCodeError, which CloudFunctions maps to a transport AuthException.
CloudFunctions _offlineCloud() => CloudFunctions(
  invoke: (_, _, _) => throw const CloudCodeError(
    code: CloudCodeErrorCode.networkUnavailable,
    message: 'offline',
  ),
  retryDelay: Duration.zero,
);

void main() {
  late CacheStore cache;
  final token = _token(42);

  setUp(() {
    useInMemoryPrefs();
    cache = CacheStore(SharedPreferencesAsync());
  });

  test('offline with a cached row, the real repo serves the cache, not an error', () async {
    await cache.write(cacheUserIdFromToken(token), 'settings', _settingsPayload);
    final repo = SettingsRepository(cloud: _offlineCloud(), cache: cache);

    final result = await repo.fetch(token);

    expect(result.offline, isTrue);
    expect(result.value.reminderIntervalMin, 45);
  });

  test('offline, Settings paints the cached row instead of the error screen', () async {
    await cache.write(cacheUserIdFromToken(token), 'settings', _settingsPayload);
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(cloud: _offlineCloud(), cache: cache),
        ),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage(token)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(settingsViewModelProvider, (_, _) {});

    final state = await container.read(settingsViewModelProvider.future);

    expect(state.settings.reminderIntervalMin, 45);
  });

  test('the offline error copy says "the cloud", never "server"', () async {
    // No cached row: the read must rethrow, and its message must not say server.
    final repo = SettingsRepository(cloud: _offlineCloud(), cache: cache);

    try {
      await repo.fetch(token);
      fail('expected the read to rethrow when nothing is cached');
    } on AuthException catch (e) {
      expect(e.message.toLowerCase(), isNot(contains('server')));
      expect(e.message.toLowerCase(), contains('cloud'));
    }
  });
}
