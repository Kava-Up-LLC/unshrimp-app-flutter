import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

import '../subscriptions/fakes.dart';

import '../../support/in_memory_prefs.dart';
import 'package:unshrimp_app/core/analytics/event_log.dart';
import 'package:unshrimp_app/core/cache/cached_read.dart';
import 'package:unshrimp_app/core/config/unshrimp_app.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/break/view_models/break_view_model.dart';
import 'package:unshrimp_app/features/exercises/repositories/exercises_repository.dart';
import 'package:unshrimp_app/features/home/models/ignore_result.dart';
import 'package:unshrimp_app/features/home/models/user_stats.dart';
import 'package:unshrimp_app/features/home/repositories/home_repository.dart';
import 'package:unshrimp_app/features/notifications/repositories/notifications_repository.dart';
import 'package:unshrimp_app/features/reconcile/models/pending_reminder.dart';
import 'package:unshrimp_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_preferences.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';
import 'package:unshrimp_app/features/roast/repositories/roast_lines_repository.dart';
import 'package:unshrimp_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../break/fakes.dart';
import '../notifications/fakes.dart';
import '../reminders/fakes.dart';
import '../settings/fakes.dart';

/// In-memory stats machine shared by the home and reconcile repositories, so a
/// reconcile that latches roast_pending and a break that clears it act on the
/// same row — the way the real server does.
class ServerStats {
  ServerStats({this.threshold = 3});

  final int threshold;
  int ignoredCount = 0;
  int roastLevel = 0;
  int breaksToday = 0;
  bool roastPending = false;

  UserStats get stats => UserStats(
    userId: 7,
    name: 'Oliver H',
    archetype: null,
    currentStreak: 0,
    breaksToday: breaksToday,
    ignoredCount: ignoredCount,
    roastLevel: roastLevel,
    roastPending: roastPending,
  );

  IgnoreResult ignore(int count) {
    ignoredCount += count;
    roastLevel = (roastLevel + count).clamp(0, UserStats.maxRoastLevel);
    if (ignoredCount >= threshold) roastPending = true;
    return IgnoreResult(ignored: count, stats: stats);
  }

  UserStats registerBreak() {
    ignoredCount = 0;
    roastLevel = (roastLevel - 1).clamp(0, UserStats.maxRoastLevel);
    breaksToday += 1;
    roastPending = false;
    return stats;
  }
}

class ServerHomeRepository implements HomeRepository {
  ServerHomeRepository(this.server);

  final ServerStats server;

  @override
  Future<CacheResult<UserStats>> fetchStats(String token) async =>
      CacheResult(value: server.stats, offline: false);

  @override
  Future<UserStats?> cachedStats(String token) async => null;

  @override
  Future<UserStats> registerBreak(String token, {required String opId}) async =>
      server.registerBreak();
}

/// The reconcile server: counts the pending reminders it is handed in one
/// atomic call and stops returning the ones it marked, like reconcile_ignored.
class ServerReconcileRepository implements ReconcileRepository {
  ServerReconcileRepository(
    this.server, {
    required List<PendingReminder> pending,
  }) : _pending = List.of(pending);

  final ServerStats server;
  List<PendingReminder> _pending;

  @override
  Future<List<PendingReminder>> fetchPending(String token) async =>
      List.of(_pending);

  @override
  Future<IgnoreResult> reconcileIgnored(
    String token, {
    required List<int> ids,
    required int tzOffsetMin,
    required String opId,
  }) async {
    _pending = _pending.where((r) => !ids.contains(r.id)).toList();
    return server.ignore(ids.length);
  }
}

void main() {
  setUp(useInMemoryPrefs);

  testWidgets('Ignored reminders -> roast -> Fix my posture -> Survived -> '
      'Home cleared', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final server = ServerStats();
    final pending = [
      for (var i = 1; i <= 3; i++)
        PendingReminder(id: i, sentAtUtc: DateTime.now().toUtc()),
    ];
    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementRepositoryProvider.overrideWithValue(FakeEntitlementRepository()),
          reconcileRepositoryProvider.overrideWithValue(
            ServerReconcileRepository(server, pending: pending),
          ),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          homeRepositoryProvider.overrideWithValue(ServerHomeRepository(server)),
          notificationsRepositoryProvider.overrideWithValue(
            FakeNotificationsRepository(),
          ),
          tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
          exercisesRepositoryProvider.overrideWithValue(
            const FakeExercisesRepository(),
          ),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          reminderNotificationsProvider.overrideWithValue(
            FakeReminderNotifications(),
          ),
          reminderPreferencesProvider.overrideWithValue(
            FakeReminderPreferences(asked: true),
          ),
          roastLinesRepositoryProvider.overrideWithValue(
            RoastLinesRepository(
              FakeReminderPreferences(),
              readConfig: (_) async => '["You had one job. The shrimp won."]',
            ),
          ),
          eventLogProvider.overrideWithValue(FakeEventLog()),
          breakTicksProvider.overrideWithValue(() => ticks.stream),
        ],
        child: const UnshrimpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Home at 100%.
    expect(find.text('Hi Oliver H'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // Open Settings, reconcile the three pending reminders as expired.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Reconcile now (debug)'), 200);
    await tester.tap(find.text('Reconcile now (debug)'));
    await tester.pumpAndSettle();

    // Threshold reached: the server latched roast_pending, and the live gate
    // routed to the roast (equivalent to the on-camera hot-restart).
    expect(server.ignoredCount, 3);
    expect(server.roastPending, isTrue);
    expect(find.text('Fix my posture'), findsOneWidget);

    // Fix my posture -> break -> Start -> 60 s -> Survived.
    await tester.tap(find.text('Fix my posture'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start'));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3 + 60; i++) {
      ticks.add(null);
      await Future<void>.microtask(() {});
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Survived'));
    await tester.tap(find.text('Survived'));
    await tester.pumpAndSettle();

    // Back to Home, cleared.
    expect(server.ignoredCount, 0);
    expect(server.roastPending, isFalse);
    expect(server.roastLevel, 2); // 3 - 1
    expect(server.breaksToday, 1);
    expect(find.text('Hi Oliver H'), findsOneWidget);
    expect(find.text('Fix my posture'), findsNothing);
    expect(find.text('60%'), findsOneWidget); // roast_level 2 -> 60%
  });
}
