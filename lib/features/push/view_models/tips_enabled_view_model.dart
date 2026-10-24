import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_notifications.dart';

/// The "Tips and news" switch: the SDK-level push toggle. Defaults to on, and
/// is independent of the reminder switches. Reads back from the SDK and writes
/// through [PushNotifications.setEnabled].
class TipsEnabledViewModel extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(pushNotificationsProvider).isEnabled();
    } catch (_) {
      return true; // Default on when the SDK can't be read.
    }
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    try {
      await ref.read(pushNotificationsProvider).setEnabled(enabled);
    } catch (_) {
      // Keep the optimistic value; the SDK persists locally and syncs later.
    }
  }
}

final tipsEnabledViewModelProvider =
    AsyncNotifierProvider<TipsEnabledViewModel, bool>(TipsEnabledViewModel.new);
