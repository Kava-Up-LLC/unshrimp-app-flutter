import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/notifications/repositories/delivery_log.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/push/services/push_background_buffer.dart';
import 'package:unshrimp_app/features/push/services/push_bridge.dart';
import 'package:unshrimp_app/features/push/view_models/push_center_recorder.dart';
import 'package:unshrimp_app/features/push/view_models/push_providers.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';

import '../auth/fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';

const _push = PushNotificationData(
  title: 'Your spine this week is ready.',
  body: 'Tap to see it.',
  data: {'open': 'report'},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(PushBridge bridge, FakeNotificationsRepository repo) => ProviderScope(
    overrides: [
      pushBridgeProvider.overrideWithValue(bridge),
      notificationsRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      deliveryLogProvider.overrideWithValue(FakeDeliveryLog()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
      eventLogProvider.overrideWithValue(FakeEventLog()),
    ],
    child: Consumer(
      builder: (_, ref, _) {
        ref.watch(pushCenterRecorderProvider);
        return const SizedBox.shrink();
      },
    ),
  );

  testWidgets('a foreground push is stored in the Center', (tester) async {
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    final repo = FakeNotificationsRepository();

    await tester.pumpWidget(host(bridge, repo));
    bridge.handleForeground(_push);
    await tester.pumpAndSettle();

    expect(repo.recordedPushes, [(title: _push.title, body: _push.body, open: 'report')]);
    expect(repo.rows.single.isPush, isTrue);
    expect(repo.rows.single.open, 'report');
  });

  testWidgets('the same push foreground then tapped records twice but is one row', (
    tester,
  ) async {
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    final repo = FakeNotificationsRepository();

    await tester.pumpWidget(host(bridge, repo));
    bridge.handleForeground(_push);
    await tester.pumpAndSettle();
    bridge.handleOpened(_push);
    await tester.pumpAndSettle();

    expect(repo.recordedPushes.length, 2); // both paths record
    expect(repo.rows.length, 1); // record_push keeps one row per push
  });

  testWidgets('pushes buffered in the background are stored on open', (
    tester,
  ) async {
    // Arrive while the app was closed (Android background handler).
    await pushBackgroundHandler(
      const PushNotificationData(title: 'BG', body: 'while closed', data: {'open': 'pro'}),
    );
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    final repo = FakeNotificationsRepository();

    await tester.pumpWidget(host(bridge, repo)); // open the app
    await tester.pumpAndSettle();

    expect(repo.recordedPushes, [(title: 'BG', body: 'while closed', open: 'pro')]);
    expect(repo.rows.single.isPush, isTrue);
    // Buffer drained, so a second open stores nothing new.
    expect(await const PushBackgroundBuffer().drain(), isEmpty);
  });
}
