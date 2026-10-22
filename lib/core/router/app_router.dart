import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/views/log_in_view.dart';
import '../../features/auth/views/session_gate_view.dart';
import '../../features/auth/views/sign_up_view.dart';
import '../../features/break/models/break_args.dart';
import '../../features/break/views/break_view.dart';
import '../../features/history/views/history_view.dart';
import '../../features/home/views/home_view.dart';
import '../../features/notifications/views/notification_center_view.dart';
import '../../features/onboarding/views/onboarding_view.dart';
import '../../features/auth/repositories/token_storage.dart';
import '../../features/reminders/repositories/reminder_preferences.dart';
import '../../features/reminders/views/reminder_permission_view.dart';
import '../../features/roast/view_models/roast_gate_provider.dart';
import '../../features/roast/views/roast_view.dart';
import '../../features/settings/views/change_password_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/subscriptions/services/pro_preferences.dart';
import '../../features/subscriptions/views/pro_view.dart';
import '../../features/subscriptions/views/trial_started_view.dart';
import 'app_routes.dart';
import 'roast_redirect.dart';

/// Single go_router instance exposed through Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever roast_pending flips (e.g. after a reconcile).
  final refresh = ValueNotifier(false);
  ref.listen(roastGateProvider, (_, _) => refresh.value = !refresh.value);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => roastRedirect(
      location: state.matchedLocation,
      pending: ref.read(roastGateProvider).pending,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.roast,
        builder: (context, state) => const RoastView(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SessionGateView(),
      ),
      GoRoute(
        path: AppRoutes.logIn,
        builder: (context, state) => const LogInView(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpView(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: AppRoutes.home,
        // Explain and ask for notification permission once, before Home.
        redirect: (context, state) async =>
            await ref.read(reminderPreferencesProvider).wasPermissionAsked()
            ? null
            : AppRoutes.reminderPermission,
        builder: (context, state) => const HomeView(),
        routes: [
          GoRoute(
            path: AppRoutes.notifications.substring(1),
            builder: (context, state) => const NotificationCenterView(),
          ),
          // Nested under Home so leaving the break returns there.
          GoRoute(
            path: AppRoutes.breakTime.substring(1),
            builder: (context, state) =>
                BreakView(args: BreakArgs.fromUri(state.uri)),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.reminderPermission,
        builder: (context, state) => const ReminderPermissionView(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryView(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordView(),
      ),
      // Shown once, right after onboarding. The redirect enforces "once": a
      // second visit (already shown) goes to Home, and it marks itself shown
      // the first time it is allowed through. Signed out → the splash gate.
      GoRoute(
        path: AppRoutes.trialStarted,
        redirect: (context, state) async {
          final token = await ref.read(tokenStorageProvider).read();
          if (token == null) return AppRoutes.splash;
          final prefs = ref.read(proPreferencesProvider);
          if (await prefs.wasTrialStartedShown()) return AppRoutes.home;
          await prefs.markTrialStartedShown();
          return null;
        },
        builder: (context, state) => const TrialStartedView(),
      ),
      // The Pro screen is reachable only with a session (so never before sign
      // up / onboarding, which is the only pre-session flow).
      GoRoute(
        path: AppRoutes.pro,
        redirect: (context, state) async =>
            await ref.read(tokenStorageProvider).read() == null
            ? AppRoutes.splash
            : null,
        builder: (context, state) => const ProView(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
