import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

import 'features/subscriptions/fakes.dart';

import 'package:unshrimp_app/core/config/unshrimp_app.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:unshrimp_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';

import 'features/auth/fakes.dart';
import 'features/home/fakes.dart';
import 'features/reconcile/fakes.dart';
import 'features/reminders/fakes.dart';

void main() {
  testWidgets('App boots into Log In when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
          reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
        ],
        child: const UnshrimpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
  });

  testWidgets('App boots into Home and shows the real stats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
          reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(asked: true),
          ),
        ],
        child: const UnshrimpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi Grace Hopper'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('2 breaks'), findsOneWidget);
    // The Pro pill pushes the CTA below the test fold; scroll it into view.
    await tester.scrollUntilVisible(
      find.text('Take a break now'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Take a break now'), findsOneWidget);
  });

  testWidgets('First time into Home explains notifications first', (
    WidgetTester tester,
  ) async {
    final scheduler = FakeReminderScheduler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
          reconcileRepositoryProvider.overrideWithValue(FakeReconcileRepository()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(),
          ),
        ],
        child: const UnshrimpApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Let Unshrimp nag you'), findsOneWidget);

    await tester.tap(find.text('Turn on reminders'));
    await tester.pumpAndSettle();

    expect(scheduler.enableCalls, 1);
    expect(find.text('Hi Grace Hopper'), findsOneWidget);
  });
}
