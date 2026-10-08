import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reconcile_view_model.dart';

/// Runs reconciliation on launch and whenever the app returns to the
/// foreground. Best-effort: a failure (offline, expired token) is swallowed —
/// Home re-fetches on its own and any missed reminders reconcile next time.
/// Watched by the root widget so it lives as long as the app.
final reconcileRunnerProvider = Provider<void>((ref) {
  Future<void> run() async {
    try {
      await ref.read(reconcileViewModelProvider).run();
    } on Exception {
      // Swallowed on purpose: see the doc comment above.
    }
  }

  // Launch.
  unawaited(run());
  // Resume.
  final listener = AppLifecycleListener(onResume: () => unawaited(run()));
  ref.onDispose(listener.dispose);
});
