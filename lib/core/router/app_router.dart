import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/views/log_in_view.dart';
import '../../features/auth/views/session_gate_view.dart';
import '../../features/auth/views/sign_up_view.dart';
import '../../features/break/models/break_args.dart';
import '../../features/break/views/break_view.dart';
import '../../features/home/views/home_view.dart';
import '../../features/notifications/views/notification_center_view.dart';
import '../../features/onboarding/views/onboarding_view.dart';
import '../../features/reminders/repositories/reminder_preferences.dart';
import '../../features/reminders/views/reminder_permission_view.dart';
import '../../features/settings/views/change_password_view.dart';
import '../../features/settings/views/settings_view.dart';
import 'app_routes.dart';

/// Single go_router instance exposed through Riverpod.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
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
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordView(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
