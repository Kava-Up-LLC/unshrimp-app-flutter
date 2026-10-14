import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_status.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/notifications/services/notification_sync.dart';
import 'package:unshrimp_app/features/notifications/view_models/notification_center_view_model.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

class _NoSync implements NotificationSync {
  @override
  Future<void> sync() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

ProviderContainer _container(FakeNotificationsRepository repo) {
  final container = ProviderContainer(
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      notificationSyncProvider.overrideWithValue(_NoSync()),
      deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
    ],
  );
  addTearDown(container.dispose);
  container.listen(notificationCenterViewModelProvider, (_, _) {});
  return container;
}

void main() {
  test('offline, the history still lists the cached notifications and flags offline', () async {
    final asOf = DateTime(2024, 1, 1, 10, 42);
    final repo = FakeNotificationsRepository(
      rows: [notification(1, DateTime(2024, 1, 1, 9))],
      offline: true,
      asOf: asOf,
    );
    final container = _container(repo);

    final list = await container.read(notificationCenterViewModelProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(list, isNotEmpty);
    expect(container.read(cacheStatusProvider).offline, isTrue);
    expect(container.read(cacheStatusProvider).asOf, asOf);
  });
}
