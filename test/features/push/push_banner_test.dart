import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/core/router/app_router.dart';
import 'package:unshrimp_app/features/push/services/push_bridge.dart';
import 'package:unshrimp_app/features/push/view_models/push_providers.dart';
import 'package:unshrimp_app/features/push/widgets/push_banner.dart';

class _FakeEventLog implements EventLog {
  final events = <String>[];
  final props = <Map<String, String>>[];

  @override
  void log(String event, [Map<String, String> properties = const {}]) {
    events.add(event);
    props.add(properties);
  }
}

void main() {
  testWidgets('a foreground push shows the banner and its tap navigates', (
    tester,
  ) async {
    final bridge = PushBridge();
    addTearDown(bridge.dispose);
    final log = _FakeEventLog();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
        GoRoute(path: '/history', builder: (_, _) => const Text('HISTORY')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushBridgeProvider.overrideWithValue(bridge),
          appRouterProvider.overrideWithValue(router),
          eventLogProvider.overrideWithValue(log),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) =>
              PushBannerHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );

    bridge.handleForeground(
      const PushNotificationData(
        title: 'Your spine this week is ready.',
        body: 'Tap to see it.',
        data: {'open': 'history'},
      ),
    );
    await tester.pump(); // deliver the stream event
    await tester.pump(); // rebuild with the banner

    expect(find.text('Your spine this week is ready.'), findsOneWidget);
    expect(find.text('Tap to see it.'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('Your spine this week is ready.'));
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('Your spine this week is ready.'), findsNothing);
    expect(log.events, contains('push_opened'));
    expect(log.props.single['open'], 'history');
  });
}
