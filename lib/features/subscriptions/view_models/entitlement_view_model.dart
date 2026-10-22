import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/token_storage.dart';
import '../models/entitlement.dart';
import '../repositories/entitlement_repository.dart';

final entitlementViewModelProvider =
    AsyncNotifierProvider.autoDispose<EntitlementViewModel, Entitlement>(
      EntitlementViewModel.new,
      // A failed read (e.g. a rejected token) should surface, not spin forever.
      retry: (_, _) => null,
    );

/// Holds the logged-in user's current [Entitlement] — the single source of
/// truth the pill, the locks and the Pro screen read. Without a session it is
/// plain Free.
class EntitlementViewModel extends AsyncNotifier<Entitlement> {
  @override
  Future<Entitlement> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return Entitlement.free;
    return ref.read(entitlementRepositoryProvider).fetch(token);
  }

  /// Re-reads the entitlement. With [bypassCache] it hits the cloud directly
  /// (used after a purchase so the pill and locks follow what the cloud says);
  /// otherwise it goes through the cache like the initial read.
  Future<void> refresh({bool bypassCache = false}) async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) {
      state = const AsyncData(Entitlement.free);
      return;
    }
    final repo = ref.read(entitlementRepositoryProvider);
    final entitlement = bypassCache
        ? await repo.refresh(token)
        : await repo.fetch(token);
    if (ref.mounted) state = AsyncData(entitlement);
  }
}
