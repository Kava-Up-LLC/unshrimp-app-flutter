import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../view_models/push_banner_view_model.dart';
import '../view_models/push_navigation.dart';

/// Wraps the app and shows the current push as a small banner at the top.
/// Tapping it navigates the same way a notification tap does; the close button
/// dismisses it. Used as the `MaterialApp.router` builder.
class PushBannerHost extends ConsumerWidget {
  const PushBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = ref.watch(pushBannerViewModelProvider);
    return Stack(
      children: [
        child,
        if (banner != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _PushBanner(
                data: banner,
                onTap: () {
                  ref.read(pushBannerViewModelProvider.notifier).dismiss();
                  openPush(ref, ref.read(appRouterProvider), banner);
                },
                onDismiss: ref
                    .read(pushBannerViewModelProvider.notifier)
                    .dismiss,
              ),
            ),
          ),
      ],
    );
  }
}

class _PushBanner extends StatelessWidget {
  const _PushBanner({
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  final PushNotificationData data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: colors.surfaceContainerHigh,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data.title case final title?)
                        Text(
                          title,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      if (data.body case final body?)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            body,
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // No tooltip: the banner floats outside the Navigator's
                // Overlay, which a tooltip would require.
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  color: colors.onSurfaceVariant,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
