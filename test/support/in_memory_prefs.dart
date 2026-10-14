import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Backs `SharedPreferencesAsync` with a fresh in-memory store, so code that
/// touches the read cache (via `CacheStore`) works without the platform plugin.
/// Call in `setUp` for tests that exercise log out / no-session cleanup.
void useInMemoryPrefs() {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
}
