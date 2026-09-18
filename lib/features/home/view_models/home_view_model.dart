import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/auth_exception.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/user_stats.dart';
import '../repositories/home_repository.dart';

final homeViewModelProvider =
    AsyncNotifierProvider.autoDispose<HomeViewModel, UserStats>(
      HomeViewModel.new,
      // Riverpod retries a failed build by default, which would keep Home
      // spinning on an expired token instead of showing the error. The user
      // retries from the error state or by logging in again.
      retry: (_, _) => null,
    );

/// Loads the logged-in user's stats and owns the log out action.
class HomeViewModel extends AsyncNotifier<UserStats> {
  @override
  Future<UserStats> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      throw const AuthException(
        code: 'INVALID_TOKEN',
        message: 'Your session has expired. Please log in again.',
      );
    }
    return ref.read(homeRepositoryProvider).fetchStats(token);
  }

  /// Reloads the stats, showing the spinner while the call is in flight.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// Clears the stored session. The view navigates back to Log In.
  Future<void> logOut() => ref.read(tokenStorageProvider).delete();
}
