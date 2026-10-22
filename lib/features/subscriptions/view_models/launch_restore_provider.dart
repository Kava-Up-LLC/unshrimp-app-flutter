import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/repositories/token_storage.dart';
import '../services/play_store.dart';
import '../services/purchase_service.dart';
import 'pro_products_provider.dart';

/// Reports what the store says is active, once per launch — because renewals
/// and cancellations are invisible to the cloud, so the only way pro_until stays
/// current is the app re-reporting active purchases on every start.
///
/// A no-op when there is no session, purchases are disabled, or the store is
/// unavailable. Reading [purchaseServiceProvider] first ensures its stream
/// listener is live to receive the restored purchases.
final launchRestoreProvider = FutureProvider<void>((ref) async {
  try {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return;
    if (!await ref.read(purchasesEnabledProvider.future)) return;
    if (!await ref.read(storeProvider).isAvailable()) return;
    await ref.read(purchaseServiceProvider).restore();
  } catch (_) {
    // Launch restore is best-effort; never let it break app start.
  }
});
