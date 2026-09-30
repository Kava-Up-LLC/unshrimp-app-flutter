import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../auth/models/auth_exception.dart';
import '../../break/models/break_args.dart';
import '../../break/models/break_source.dart';
import '../view_models/notification_center_view_model.dart';
import '../widgets/notification_tile.dart';

/// Notification Center: every reminder the user got, newest first. Tapping
/// one marks it read and opens the 60 s break.
class NotificationCenterView extends ConsumerWidget {
  const NotificationCenterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationCenterViewModelProvider);
    final viewModel = ref.read(notificationCenterViewModelProvider.notifier);

    // A rejected token means the session is over, wherever it was rejected.
    ref.listen(notificationCenterViewModelProvider, (_, next) {
      final error = next.error;
      if (error is AuthException && error.code == 'INVALID_TOKEN') {
        context.go(AppRoutes.logIn);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: switch (notifications) {
          AsyncData(:final value) => RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: value.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(48),
                    children: const [
                      Center(child: Text('No reminders yet. Enjoy it.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: value.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = value[index];
                      return NotificationTile(
                        notification: notification,
                        onTap: () {
                          viewModel.opened(notification);
                          context.push(
                            const BreakArgs(
                              source: BreakSource.center,
                            ).location,
                          );
                        },
                      );
                    },
                  ),
          ),
          AsyncError(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is AuthException
                      ? error.message
                      : 'Something went wrong. Please try again.',
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: viewModel.refresh,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
