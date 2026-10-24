import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/push/services/push_notifications.dart';
import 'package:unshrimp_app/features/push/view_models/tips_enabled_view_model.dart';

import 'fakes.dart';

ProviderContainer _container(FakePushNotifications push) {
  final container = ProviderContainer(
    overrides: [pushNotificationsProvider.overrideWithValue(push)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('reads the SDK toggle on build', () async {
    final push = FakePushNotifications(enabled: false);
    final c = _container(push);

    final value = await c.read(tipsEnabledViewModelProvider.future);

    expect(value, isFalse);
  });

  test('defaults to on when the SDK cannot be read', () async {
    final push = FakePushNotifications(throwOnRead: true);
    final c = _container(push);

    final value = await c.read(tipsEnabledViewModelProvider.future);

    expect(value, isTrue);
  });

  test('set writes through to the SDK and persists optimistically', () async {
    final push = FakePushNotifications(enabled: true);
    final c = _container(push);
    await c.read(tipsEnabledViewModelProvider.future);

    await c.read(tipsEnabledViewModelProvider.notifier).set(false);

    expect(push.lastSetEnabled, isFalse);
    expect(c.read(tipsEnabledViewModelProvider).value, isFalse);
  });
}
