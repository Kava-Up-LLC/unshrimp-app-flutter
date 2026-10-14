import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_prefs.dart';
import 'package:move_well_app/features/auth/repositories/token_storage.dart';
import 'package:move_well_app/features/home/repositories/home_repository.dart';
import 'package:move_well_app/features/reconcile/models/pending_reminder.dart';
import 'package:move_well_app/features/reconcile/models/reconcile_status.dart';
import 'package:move_well_app/features/reconcile/repositories/reconcile_repository.dart';
import 'package:move_well_app/features/reconcile/view_models/reconcile_view_model.dart';
import 'package:move_well_app/features/settings/repositories/settings_repository.dart';

import '../auth/fakes.dart';
import '../home/fakes.dart';
import '../settings/fakes.dart';
import 'fakes.dart';

/// Builds a UTC instant whose LOCAL wall clock is [hour]:[minute], so the
/// window math is the same whatever timezone the test runner is in.
DateTime _sentAtLocal(int hour, int minute) =>
    DateTime(2026, 1, 15, hour, minute).toUtc();

PendingReminder _pending(int id, {int hour = 10, int minute = 0}) =>
    PendingReminder(id: id, sentAtUtc: _sentAtLocal(hour, minute));

ProviderContainer _container(
  FakeReconcileRepository reconcile, {
  FakeHomeRepository? home,
}) {
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage('t')),
      reconcileRepositoryProvider.overrideWithValue(reconcile),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      homeRepositoryProvider.overrideWithValue(home ?? FakeHomeRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(useInMemoryPrefs);

  group('isExpired (device-local)', () {
    const graceMin = 30;
    const start = '09:00';
    const end = '18:00';

    bool expired(DateTime sentUtc, DateTime now) => ReconcileViewModel.isExpired(
      sentAtUtc: sentUtc,
      now: now,
      graceMin: graceMin,
      activeStart: start,
      activeEnd: end,
    );

    test('in window and past the grace window -> expired', () {
      expect(expired(_sentAtLocal(10, 0), DateTime(2026, 1, 15, 10, 31)), isTrue);
    });

    test('in window but still inside the grace window -> not expired', () {
      expect(expired(_sentAtLocal(10, 0), DateTime(2026, 1, 15, 10, 20)), isFalse);
    });

    test('sent before the active window -> not expired', () {
      expect(expired(_sentAtLocal(8, 0), DateTime(2026, 1, 15, 12, 0)), isFalse);
    });

    test('sent at the exact window end -> not expired', () {
      expect(expired(_sentAtLocal(18, 0), DateTime(2026, 1, 15, 20, 0)), isFalse);
    });
  });

  group('run', () {
    test('counts the expired rows, marks them, and sends tz_offset_min', () async {
      final reconcile = FakeReconcileRepository([
        _pending(1),
        _pending(2),
        _pending(3),
      ]);
      final c = _container(reconcile);

      final outcome = await c.read(reconcileViewModelProvider).run(forceAll: true);

      expect(outcome.status, ReconcileStatus.counted);
      expect(outcome.ignored, 3);
      expect(reconcile.reconcileCalls, 1);
      expect(reconcile.lastTzOffsetMin, DateTime.now().timeZoneOffset.inMinutes);
      expect(reconcile.reconciledIds.single, [1, 2, 3]);
    });

    test('does not count the same rows twice across runs', () async {
      final reconcile = FakeReconcileRepository([_pending(1), _pending(2)]);
      final c = _container(reconcile);
      final vm = c.read(reconcileViewModelProvider);

      await vm.run(forceAll: true);
      final second = await vm.run(forceAll: true);

      expect(second.status, ReconcileStatus.nothingPending);
      expect(reconcile.reconcileCalls, 1); // not called the second time
    });

    test('outside active hours (counted: 0) marks nothing', () async {
      final reconcile = FakeReconcileRepository([_pending(1), _pending(2)], 0);
      final c = _container(reconcile);

      final outcome = await c.read(reconcileViewModelProvider).run(forceAll: true);

      expect(outcome.status, ReconcileStatus.notCounted);
      expect(reconcile.reconcileCalls, 1);
      expect(reconcile.reconciledIds, isEmpty);
    });

    test('nothing pending does nothing', () async {
      final reconcile = FakeReconcileRepository(const []);
      final c = _container(reconcile);

      final outcome = await c.read(reconcileViewModelProvider).run(forceAll: true);

      expect(outcome.status, ReconcileStatus.nothingPending);
      expect(reconcile.reconcileCalls, 0);
    });
  });
}
