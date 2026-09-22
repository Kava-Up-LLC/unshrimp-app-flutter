import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/views/log_in_view.dart';
import '../../features/auth/views/session_gate_view.dart';
import '../../features/auth/views/sign_up_view.dart';
import '../../features/home/views/home_view.dart';
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
        path: AppRoutes.home,
        builder: (context, state) => const HomeView(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
