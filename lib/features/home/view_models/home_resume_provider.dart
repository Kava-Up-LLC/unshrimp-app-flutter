import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_view_model.dart';

/// Re-reads Home's stats whenever the app returns to the foreground, but only
/// while Home is actually mounted (so the work happens exactly when the offline
/// indicator is on screen). A successful read clears the "Offline as of…"
/// marker and, via the read tick, drains the write outbox.
///
/// Lives in its own root-watched provider rather than inside
/// [HomeViewModel.build] because [AppLifecycleListener] needs a widgets binding
/// — putting it in the view model would break plain (non-widget) unit tests.
final homeResumeProvider = Provider<void>((ref) {
  final listener = AppLifecycleListener(
    onResume: () {
      if (ref.exists(homeViewModelProvider)) {
        unawaited(ref.read(homeViewModelProvider.notifier).revalidate());
      }
    },
  );
  ref.onDispose(listener.dispose);
});
