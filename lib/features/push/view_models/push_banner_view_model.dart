import 'dart:async';

import 'package:appambit_sdk_push_notifications/appambit_sdk_push_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_providers.dart';

/// Holds the push currently shown as the top in-app banner, or null. A new
/// foreground push replaces it and (re)starts the four-second auto-dismiss.
class PushBannerViewModel extends Notifier<PushNotificationData?> {
  Timer? _timer;

  @override
  PushNotificationData? build() {
    ref.listen(pushForegroundProvider, (_, next) {
      if (next case AsyncData(:final value)) show(value);
    });
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(PushNotificationData data) {
    _timer?.cancel();
    state = data;
    _timer = Timer(const Duration(seconds: 4), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }
}

final pushBannerViewModelProvider =
    NotifierProvider<PushBannerViewModel, PushNotificationData?>(
      PushBannerViewModel.new,
    );
