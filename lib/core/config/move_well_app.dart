import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/break/models/break_args.dart';
import '../../features/reconcile/view_models/reconcile_runner_provider.dart';
import '../../features/reminders/view_models/reminder_resume_provider.dart';
import '../../features/reminders/view_models/reminder_taps_provider.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// Root widget: wires the go_router instance, the app theme and reminder
/// taps.
class MoveWellApp extends ConsumerWidget {
  const MoveWellApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(reminderResumeProvider);
    ref.watch(reconcileRunnerProvider);

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
