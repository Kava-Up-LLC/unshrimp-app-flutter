import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/models/purchase_result.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_product.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_purchase.dart';
import 'package:unshrimp_app/features/subscriptions/services/purchase_service.dart';

import 'fakes.dart';

const _product = StoreProduct(id: 'unshrimp_pro_yearly', price: r'$14.99/yr');

StorePurchase _purchase(StorePurchaseStatus status) => StorePurchase(
  productId: _product.id,
  status: status,
  originalJson: '{"productId":"unshrimp_pro_yearly"}',
  signature: 'sig',
);

const _pro = Entitlement(isPro: true, entitlement: 'pro');

PurchaseService _service(
  FakeStore store,
  FakeSubscriptionRepository repo, {
  int Function()? onChange,
}) => PurchaseService(
  store: store,
  repository: repo,
  readToken: () async => 'tok',
  newOpId: () => 'op-test',
  onEntitlementChanged: () async => onChange?.call(),
);

void main() {
  test('a granted purchase is acknowledged and returns purchased', () async {
    final store = FakeStore();
    final repo = FakeSubscriptionRepository(onGrant: () => _pro);
    var changed = 0;
    final service = _service(store, repo, onChange: () => ++changed);
    addTearDown(service.dispose);
    addTearDown(store.dispose);

    final result = service.buy(_product);
    store.emit([_purchase(StorePurchaseStatus.purchased)]);

    expect(await result, PurchaseResult.purchased);
    expect(repo.grantCalls, 1);
    expect(repo.grantedOpIds.single, 'op-test');
    expect(store.completed.length, 1); // acknowledged
    expect(changed, 1); // UI told Pro is live
  });

  test('a purchase is NOT acknowledged when grant_entitlement fails', () async {
    final store = FakeStore();
    final repo = FakeSubscriptionRepository(onGrant: null); // grant throws
    var changed = 0;
    final service = _service(store, repo, onChange: () => ++changed);
    addTearDown(service.dispose);
    addTearDown(store.dispose);

    final result = service.buy(_product);
    store.emit([_purchase(StorePurchaseStatus.purchased)]);

    expect(await result, PurchaseResult.failed);
    expect(repo.grantCalls, 1);
    expect(store.completed, isEmpty); // left unacknowledged for redelivery
    expect(changed, 0);
  });

  test('a cancelled sheet returns cancelled and grants nothing', () async {
    final store = FakeStore();
    final repo = FakeSubscriptionRepository(onGrant: () => _pro);
    final service = _service(store, repo);
    addTearDown(service.dispose);
    addTearDown(store.dispose);

    final result = service.buy(_product);
    store.emit([_purchase(StorePurchaseStatus.canceled)]);

    expect(await result, PurchaseResult.cancelled);
    expect(repo.grantCalls, 0);
    expect(store.completed, isEmpty);
  });

  test('restore reports active purchases and acknowledges after cloud OK', () async {
    final store = FakeStore();
    final repo = FakeSubscriptionRepository(onRestore: () => _pro);
    var changed = 0;
    final service = _service(store, repo, onChange: () => ++changed);
    addTearDown(service.dispose);
    addTearDown(store.dispose);

    await service.restore();
    expect(store.restoreCalled, isTrue);

    store.emit([_purchase(StorePurchaseStatus.restored)]);
    await pumpEventQueue();

    expect(repo.restoreCalls, 1);
    expect(store.completed.length, 1);
    expect(changed, 1);
  });
}
