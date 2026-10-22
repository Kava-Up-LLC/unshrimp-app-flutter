import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outbox/op_id.dart';
import '../../auth/repositories/token_storage.dart';
import '../models/purchase_result.dart';
import '../models/store_purchase.dart';
import '../models/store_product.dart';
import '../repositories/subscription_repository.dart';
import '../view_models/entitlement_view_model.dart';
import 'play_store.dart';
import 'store.dart';

/// Drives the store purchase flow and keeps the cloud as the only thing that
/// decides Pro.
///
/// It listens to the store's purchase stream for the app's lifetime. For a new
/// purchase it calls `grant_entitlement`; for a restored one `restore_entitlement`.
/// A purchase is **acknowledged (completed) only after the cloud answers OK** —
/// a failed grant leaves it unacknowledged, so the store redelivers it on the
/// next launch and `restore` picks it up.
class PurchaseService {
  PurchaseService({
    required Store store,
    required SubscriptionRepository repository,
    required Future<String?> Function() readToken,
    String Function() newOpId = newOpId,
    Future<void> Function()? onEntitlementChanged,
  }) : _store = store,
       _repo = repository,
       _readToken = readToken,
       _newOpId = newOpId,
       _onEntitlementChanged = onEntitlementChanged {
    _sub = _store.purchaseStream.listen(_onPurchases);
  }

  final Store _store;
  final SubscriptionRepository _repo;
  final Future<String?> Function() _readToken;
  final String Function() _newOpId;
  final Future<void> Function()? _onEntitlementChanged;

  late final StreamSubscription<List<StorePurchase>> _sub;
  final _pending = <String, Completer<PurchaseResult>>{};

  /// Opens the store sheet for [product] and resolves when that product's
  /// purchase reaches a terminal state. Returns `purchased` only after the cloud
  /// grant succeeds.
  Future<PurchaseResult> buy(StoreProduct product) {
    final completer = Completer<PurchaseResult>();
    _pending[product.id] = completer;
    _store.buy(product).catchError((_) => _resolve(product.id, PurchaseResult.failed));
    return completer.future;
  }

  /// Asks the store to re-deliver active purchases; each arrives on the stream
  /// as `restored` and is reported to the cloud.
  Future<void> restore() => _store.restore();

  Future<void> dispose() => _sub.cancel();

  void _resolve(String productId, PurchaseResult result) {
    _pending.remove(productId)?.complete(result);
  }

  Future<void> _onPurchases(List<StorePurchase> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case StorePurchaseStatus.pending:
          break; // still in flight; keep waiting
        case StorePurchaseStatus.canceled:
          _resolve(purchase.productId, PurchaseResult.cancelled);
        case StorePurchaseStatus.error:
          _resolve(purchase.productId, PurchaseResult.failed);
        case StorePurchaseStatus.purchased:
          await _grant(purchase);
        case StorePurchaseStatus.restored:
          await _restore(purchase);
      }
    }
  }

  Future<void> _grant(StorePurchase purchase) async {
    try {
      final token = await _readToken();
      if (token == null) {
        _resolve(purchase.productId, PurchaseResult.failed);
        return;
      }
      await _repo.grant(
        token: token,
        productId: purchase.productId,
        payload: purchase.originalJson,
        signature: purchase.signature,
        opId: _newOpId(),
      );
      // Granted: safe to acknowledge, then tell the UI Pro is live.
      await _store.complete(purchase);
      await _onEntitlementChanged?.call();
      _resolve(purchase.productId, PurchaseResult.purchased);
    } catch (_) {
      // Not granted: leave the purchase unacknowledged for redelivery.
      _resolve(purchase.productId, PurchaseResult.failed);
    }
  }

  Future<void> _restore(StorePurchase purchase) async {
    try {
      final token = await _readToken();
      if (token == null) return;
      await _repo.restore(
        token: token,
        purchases: [
          {'payload': purchase.originalJson, 'signature': purchase.signature},
        ],
      );
      await _store.complete(purchase);
      await _onEntitlementChanged?.call();
    } catch (_) {
      // Leave it unacknowledged; the next launch tries again.
    }
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService(
    store: ref.read(storeProvider),
    repository: ref.read(subscriptionRepositoryProvider),
    readToken: ref.read(tokenStorageProvider).read,
    onEntitlementChanged: () =>
        ref.read(entitlementViewModelProvider.notifier).refresh(bypassCache: true),
  );
  ref.onDispose(service.dispose);
  return service;
});
