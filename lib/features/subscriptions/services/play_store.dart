import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../models/store_product.dart';
import '../models/store_purchase.dart';
import 'store.dart';

/// The real [Store], backed by Google Play Billing through `in_app_purchase`.
///
/// On Android the signed receipt (the original JSON and its signature) lives on
/// [GooglePlayPurchaseDetails.billingClientPurchase]; that pair is what the
/// cloud verifies. `verificationData.serverVerificationData` is only the
/// purchase token, so it is not used for the signature check.
class PlayStore implements Store {
  PlayStore({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    return response.productDetails
        .map((p) => StoreProduct(id: p.id, price: p.price, raw: p))
        .toList();
  }

  @override
  Stream<List<StorePurchase>> get purchaseStream =>
      _iap.purchaseStream.map((list) => list.map(_toStorePurchase).toList());

  @override
  Future<void> buy(StoreProduct product) async {
    final details = product.raw;
    if (details is! ProductDetails) return;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(StorePurchase purchase) async {
    final raw = purchase.raw;
    if (raw is PurchaseDetails && raw.pendingCompletePurchase) {
      await _iap.completePurchase(raw);
    }
  }

  StorePurchase _toStorePurchase(PurchaseDetails d) {
    var originalJson = '';
    var signature = '';
    if (d is GooglePlayPurchaseDetails) {
      originalJson = d.billingClientPurchase.originalJson;
      signature = d.billingClientPurchase.signature;
    }
    return StorePurchase(
      productId: d.productID,
      status: _status(d.status),
      originalJson: originalJson,
      signature: signature,
      raw: d,
    );
  }

  StorePurchaseStatus _status(PurchaseStatus s) => switch (s) {
    PurchaseStatus.pending => StorePurchaseStatus.pending,
    PurchaseStatus.purchased => StorePurchaseStatus.purchased,
    PurchaseStatus.restored => StorePurchaseStatus.restored,
    PurchaseStatus.error => StorePurchaseStatus.error,
    PurchaseStatus.canceled => StorePurchaseStatus.canceled,
  };
}

final storeProvider = Provider<Store>((ref) => PlayStore());
