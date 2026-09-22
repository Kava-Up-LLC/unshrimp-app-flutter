import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/session_status.dart';
import '../view_models/session_gate_view_model.dart';

/// Splash shown at launch while the stored session is validated.
class SessionGateView extends ConsumerWidget {
  const SessionGateView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionGateViewModelProvider, (_, next) {
      switch (next) {
        case AsyncData(value: SessionStatus.authenticated):
          context.go(AppRoutes.home);
        case AsyncData() || AsyncError():
          context.go(AppRoutes.logIn);
        default:
          break;
      }
    });
    ref.watch(sessionGateViewModelProvider);

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
