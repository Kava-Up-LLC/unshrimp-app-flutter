import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/push/services/push_bridge.dart';

void main() {
  test('launchOpen captures the tap even when the opened stream has a listener',
      () async {
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    // Mimic launch: the UI already subscribed when the SDK delivers the tap.
    bridge.opened().listen((_) {});
    await Future<void>.delayed(Duration.zero); // let the subscription attach

    bridge.handleOpened(const PushNotificationData(data: {'open': 'report'}));

    expect(bridge.launchOpen?.data?['open'], 'report');
  });

  test('launchOpen is null before any tap', () {
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    expect(bridge.launchOpen, isNull);
  });
}
