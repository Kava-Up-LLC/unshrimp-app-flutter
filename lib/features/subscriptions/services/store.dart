import '../models/store_product.dart';
import '../models/store_purchase.dart';

/// The thin store surface the subscriptions feature needs, so the purchase flow
/// can be driven by a fake in tests. The real implementation ([PlayStore])
/// wraps `in_app_purchase`.
abstract class Store {
  /// Whether in-app purchases are available on this device.
  Future<bool> isAvailable();

  /// The store's details (localized price) for [ids]. Ids the store does not
  /// know are simply absent from the result.
  Future<List<StoreProduct>> queryProducts(Set<String> ids);

  /// Every purchase update the store emits: new buys, restores and errors.
  Stream<List<StorePurchase>> get purchaseStream;

  /// Opens the store's purchase sheet for [product].
  Future<void> buy(StoreProduct product);

  /// Asks the store to re-deliver the user's active purchases on [purchaseStream].
  Future<void> restore();

  /// Acknowledges [purchase] with the store. Called ONLY after the cloud grants,
  /// so an unverified purchase is never acknowledged and the store redelivers it.
  Future<void> complete(StorePurchase purchase);
}
