import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_exception.dart';
import '../repositories/auth_repository.dart';
import '../repositories/token_storage.dart';

/// On app resume, if the stored token is more than a day into its 7-day window,
/// exchange it for a fresh one via `auth_refresh`, so an active user is never
/// logged out while a user who disappears for a week still is. The swap is
/// all-or-nothing: on any failure the old pair stays, to be used until it
/// actually expires. Watched by the root widget so it lives as long as the app.
final sessionRefreshProvider = Provider<void>((ref) {
  Future<void> maybeRefresh() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.read();
    if (token == null) return;

    final expiresAt = await storage.readExpiresAt();
    // Legacy token with no stored expiry: leave it for the next login to
    // replace rather than guess its age.
    if (expiresAt == null) return;

    // More than a day old == less than six days left in the seven-day window.
    final stillFresh = expiresAt.isAfter(
      DateTime.now().add(const Duration(days: 6)),
    );
    if (stillFresh) return;

    try {
      final session = await ref.read(authRepositoryProvider).refresh(token);
      await storage.writeSession(session);
    } on AuthException {
      // Keep the old token; it still works until it really expires.
    }
  }

  final listener = AppLifecycleListener(
    onResume: () => unawaited(maybeRefresh()),
  );
  ref.onDispose(listener.dispose);
});
