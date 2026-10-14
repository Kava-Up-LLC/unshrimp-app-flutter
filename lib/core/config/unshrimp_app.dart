import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/view_models/session_refresh_provider.dart';
import '../../features/break/models/break_args.dart';
import '../../features/home/view_models/home_resume_provider.dart';
import '../../features/reconcile/view_models/reconcile_runner_provider.dart';
import '../../features/reminders/view_models/reminder_resume_provider.dart';
import '../../features/reminders/view_models/reminder_taps_provider.dart';
import '../../features/roast/view_models/roast_gate_provider.dart';
import '../../features/update_gate/views/update_required_view.dart';
import '../outbox/outbox.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// Root widget: wires the go_router instance, the app theme and reminder
/// taps.
class UnshrimpApp extends ConsumerWidget {
  const UnshrimpApp({super.key, this.updateRequired = false});

  /// When true, the build is below `min_supported_version`: the app shows only
  /// the blocking update wall and never mounts the router or its startup
  /// providers, so there is no way around it.
  final bool updateRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (updateRequired) {
      return MaterialApp(
        title: 'Unshrimp',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const UpdateRequiredView(),
      );
    }

    final router = ref.watch(appRouterProvider);
    ref.watch(reminderResumeProvider);
    ref.watch(sessionRefreshProvider);
    ref.watch(reconcileRunnerProvider);
    // Flush the write outbox on launch/resume, and keep the roast gate's local
    // "released" flag in sync with it (a queued completed break releases the
    // roast offline and survives a cold start).
    ref.watch(outboxRunnerProvider);
    ref.watch(roastReleaseFeederProvider);
    // Re-read Home on resume so a reconnect clears the offline marker.
    ref.watch(homeResumeProvider);

    // A reminder tapped while the app runs opens its break. Taps that launch
    // the app are handled by the session gate.
    ref.listen(reminderTapsProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        router.go(BreakArgs.fromReminderPayload(value).location);
      }
    });

    return MaterialApp.router(
      title: 'Unshrimp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
