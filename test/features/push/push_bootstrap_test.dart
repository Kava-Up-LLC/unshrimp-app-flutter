import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/push/services/push_bootstrap.dart';

import 'fakes.dart';

void main() {
  test('without an App Key push never starts', () async {
    final push = FakePushNotifications();

    final bridge = await startPush('', push);

    expect(bridge, isNull);
    expect(push.startCalls, 0);
    expect(push.foregroundListener, isNull);
    expect(push.openedListener, isNull);
  });

  test('with an App Key push starts and wires both listeners', () async {
    final push = FakePushNotifications();

    final bridge = await startPush('app-key', push);

    expect(bridge, isNotNull);
    expect(push.startCalls, 1);
    expect(push.foregroundListener, isNotNull);
    expect(push.openedListener, isNotNull);
  });

  test('a cold-start tap is buffered and replayed on first listen', () async {
    final push = FakePushNotifications();
    final bridge = (await startPush('app-key', push))!;

    // Tap arrives (cold start) before the UI subscribes.
    push.openedListener!(const PushNotificationData(data: {'open': 'report'}));

    final first = await bridge.opened().first;
    expect(first.data?['open'], 'report');
  });
}
