import 'package:appambit_sdk_flutter/appambit_sdk_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote Config key holding the lowest build version allowed to run.
const minSupportedVersionKey = 'min_supported_version';

/// Remote Config key holding the store listing URL the update screen opens.
const updateStoreUrlKey = 'update_url';

/// Whether [running] is strictly below [minimum], comparing dotted numeric
/// versions component by component (`1.9.0` < `1.10.0`). Build and pre-release
/// suffixes (`+42`, `-beta`) are ignored. If either side has no usable numeric
/// component the result is `false`: a version we cannot read is never treated
/// as outdated.
bool isVersionBelow(String running, String minimum) {
  final a = _parse(running);
  final b = _parse(minimum);
  if (a.isEmpty || b.isEmpty) return false;

  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (left != right) return left < right;
  }
  return false;
}

List<int> _parse(String version) {
  final core = version.trim().split(RegExp(r'[+-]')).first;
  if (core.isEmpty) return const [];
  final parts = <int>[];
  for (final segment in core.split('.')) {
    final value = int.tryParse(segment.trim());
    if (value == null) return const []; // malformed: treat as unreadable
    parts.add(value);
  }
  return parts;
}

/// Reads [minSupportedVersionKey] from Remote Config and compares it against the
/// running build version. Returns `true` only when the build is confidently
/// below the minimum.
///
/// Defaults to permissive: a missing, empty or malformed key, an unreadable
/// running version, or any thrown error all return `false` so a failed config
/// fetch can never lock a user out of their own app.
Future<bool> isUpdateRequired({
  Future<String?> Function(String key)? readConfig,
  Future<String> Function()? currentVersion,
}) async {
  final read = readConfig ?? AppAmbitSdk.getString;
  final version = currentVersion ?? _runningVersion;
  try {
    final minimum = (await read(minSupportedVersionKey))?.trim() ?? '';
    if (minimum.isEmpty) return false;
    return isVersionBelow(await version(), minimum);
  } catch (_) {
    // Remote Config or package info unavailable: let the app run.
    return false;
  }
}

Future<String> _runningVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// Reads [updateStoreUrlKey] from Remote Config. Returns `null` when the key is
/// absent, empty or unreadable, in which case the update screen hides its
/// button instead of opening a hardcoded URL.
Future<String?> updateStoreUrl({
  Future<String?> Function(String key)? readConfig,
}) async {
  final read = readConfig ?? AppAmbitSdk.getString;
  try {
    final url = (await read(updateStoreUrlKey))?.trim() ?? '';
    return url.isEmpty ? null : url;
  } catch (_) {
    return null;
  }
}
