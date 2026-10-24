import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/view_models/session_refresh_provider.dart';
import '../../features/break/models/break_args.dart';
import '../../features/home/view_models/home_resume_provider.dart';
import '../../features/reconcile/view_models/reconcile_runner_provider.dart';
import '../../features/push/view_models/push_center_recorder.dart';
import '../../features/push/view_models/push_navigation.dart';
import '../../features/push/view_models/push_providers.dart';
import '../../features/push/widgets/push_banner.dart';
import '../../features/reminders/view_models/reminder_resume_provider.dart';
import '../../features/reminders/view_models/reminder_taps_provider.dart';
import '../../features/roast/view_models/roast_gate_provider.dart';
import '../../features/subscriptions/view_models/launch_restore_provider.dart';
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
    // Report the store's active purchases once per launch so pro_until stays
    // current (renewals/cancellations are invisible to the cloud). A no-op when
    // signed out, purchases disabled, or the store is unavailable.
    ref.watch(launchRestoreProvider);
    // Store every received push (foreground or tapped) in the Notification
    // Center so it shows there with the bell badge.
    ref.watch(pushCenterRecorderProvider);

    // A reminder tapped while the app runs opens its break (or the screen it
    // names, e.g. the Spine Report → History). Taps that launch the app are
    // handled by the session gate.
    ref.listen(reminderTapsProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        router.go(reminderTapLocation(value));
      }
    });

    // A tapped push (foreground, background, or the tap that launched the app)
    // navigates by its `open` key. A cold-start tap is buffered and replayed
    // here once the router is up, so it lands after the splash.
    ref.listen(pushOpenedProvider, (_, next) {
      if (next case AsyncData(:final value)) {
        openPush(ref, router, value);
      }
    });

    return MaterialApp.router(
      title: 'Unshrimp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) =>
          PushBannerHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
