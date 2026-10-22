import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_result.dart';
import '../models/store_product.dart';
import '../services/purchase_service.dart';

final purchaseViewModelProvider = NotifierProvider<PurchaseViewModel, bool>(
  PurchaseViewModel.new,
);

/// Drives Subscribe and Restore from the Pro screen. The state is whether a
/// purchase is in flight, so the button shows a spinner and the screen ignores
/// taps while it runs.
class PurchaseViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  /// Buys [product]; a second call while one is in flight is ignored.
  Future<PurchaseResult> buy(StoreProduct product) async {
    if (state) return PurchaseResult.cancelled;
    state = true;
    try {
      return await ref.read(purchaseServiceProvider).buy(product);
    } finally {
      state = false;
    }
  }

  /// Asks the store to re-deliver active purchases (the cloud recomputes Pro).
  Future<void> restore() => ref.read(purchaseServiceProvider).restore();
}
