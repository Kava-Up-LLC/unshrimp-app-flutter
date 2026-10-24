import '../../../core/router/app_routes.dart';

/// Where a tapped push opens, from its `open` custom-data key. The value is a
/// go_router location handed to the same navigation the reminder taps use.
/// Anything unknown or missing opens Home.
String pushOpenLocation(String? open) => switch (open) {
  'history' => AppRoutes.history,
  'pro' => AppRoutes.pro,
  // History scrolled to the Spine Report card (see HistoryView's `focus`).
  'report' => '${AppRoutes.history}?focus=report',
  _ => AppRoutes.home,
};
