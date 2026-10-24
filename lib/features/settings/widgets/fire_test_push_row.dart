import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../push/view_models/push_providers.dart';
import 'settings_row.dart';

/// Debug only: injects a fake foreground push into the live PushBridge, exactly
/// as if one had arrived from the backend, so the in-app banner and its tap
/// navigation can be demoed or recorded without a remote send.
class FireTestPushRow extends ConsumerWidget {
  const FireTestPushRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.watch(pushBridgeProvider);
    return SettingsRow(
      label: 'Fire test push (debug)',
      subtitle: 'Debug only. Shows the in-app push banner (open=report).',
      trailing: const Icon(Icons.campaign_outlined),
      onTap: bridge == null
          ? null
          : () => bridge.handleForeground(
              const PushNotificationData(
                title: 'Your spine this week is ready.',
                body: 'Tap to see your Spine Report.',
                data: {'open': 'report'},
              ),
            ),
    );
  }
}
