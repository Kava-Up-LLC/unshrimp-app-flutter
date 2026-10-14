import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/auth/models/auth_exception.dart';
import 'package:unshrimp_app/features/auth/repositories/auth_repository.dart';
import 'package:unshrimp_app/features/auth/repositories/token_storage.dart';
import 'package:unshrimp_app/features/auth/models/session_status.dart';
import 'package:unshrimp_app/features/auth/view_models/session_gate_view_model.dart';
import 'package:unshrimp_app/features/reminders/repositories/reminder_notifications.dart';
import 'package:unshrimp_app/features/reminders/services/reminder_scheduler.dart';

import 'fakes.dart';
import '../reminders/fakes.dart';

ProviderContainer _container(FakeTokenStorage store, FakeAuthRepository auth) {
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(auth),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      reminderNotificationsProvider.overrideWithValue(FakeReminderNotifications()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final future = DateTime.now().add(const Duration(days: 3));
  final past = DateTime.now().subtract(const Duration(minutes: 1));

  test('a token with a future expiry opens the app without calling validate', () async {
    final store = FakeTokenStorage('t', future);
    final auth = FakeAuthRepository();
    final start = await _container(store, auth).read(sessionGateViewModelProvider.future);

    expect(start.status, SessionStatus.authenticated);
    expect(auth.validateCalls, 0); // offline-first: no validate on the hot path
    expect(store.token, 't'); // token kept
  });

  test('a token whose stored expiry has passed goes to Log In and is cleared', () async {
    final store = FakeTokenStorage('t', past);
    final auth = FakeAuthRepository();
    final start = await _container(store, auth).read(sessionGateViewModelProvider.future);

    expect(start.status, SessionStatus.unauthenticated);
    expect(auth.validateCalls, 0);
    expect(store.token, isNull); // pair cleared
  });

  test('a legacy token (no stored expiry) is confirmed online once', () async {
    final store = FakeTokenStorage('legacy'); // null expiry
    final auth = FakeAuthRepository(valid: true);
    final start = await _container(store, auth).read(sessionGateViewModelProvider.future);

    expect(start.status, SessionStatus.authenticated);
    expect(auth.validateCalls, 1);
  });

  test('a legacy token rejected with INVALID_TOKEN logs out and clears it', () async {
    final store = FakeTokenStorage('legacy');
    final auth = FakeAuthRepository(
      validateError: const AuthException(code: 'INVALID_TOKEN', message: 'gone'),
    );
    final start = await _container(store, auth).read(sessionGateViewModelProvider.future);

    expect(start.status, SessionStatus.unauthenticated);
    expect(store.token, isNull);
  });

  test('a legacy token with a transport failure is forgiven (app opens)', () async {
    final store = FakeTokenStorage('legacy');
    final auth = FakeAuthRepository(
      validateError: const AuthException(code: 'http', message: 'offline'),
    );
    final start = await _container(store, auth).read(sessionGateViewModelProvider.future);

    expect(start.status, SessionStatus.authenticated);
    expect(store.token, 'legacy'); // kept, not cleared
  });
}
