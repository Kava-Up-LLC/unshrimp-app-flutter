import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'version_gate.dart';

/// The store listing URL for the update screen, read from Remote Config. Null
/// when the key is absent, empty or unreadable, in which case the screen hides
/// its button instead of opening a hardcoded URL.
final updateStoreUrlProvider = FutureProvider<String?>(
  (ref) => updateStoreUrl(),
);

/// Opens the store listing in the external store app / browser. Returns whether
/// the launch was accepted; the view uses it to keep the user on the wall if the
/// link cannot be opened.
Future<bool> openStoreListing(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
