import 'dart:async';

import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_product.dart';
import 'package:unshrimp_app/features/subscriptions/models/store_purchase.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/subscription_repository.dart';
import 'package:unshrimp_app/features/subscriptions/services/store.dart';

/// Entitlement repository for widget tests: returns a fixed entitlement with no
/// network call, so rendering Home (pill + trial-ended host) or a break never
/// reaches the real Cloud Code path. Defaults to Free.
class FakeEntitlementRepository implements EntitlementRepository {
  FakeEntitlementRepository([this.entitlement = Entitlement.free]);

  final Entitlement entitlement;

  @override
  Future<Entitlement> fetch(String token) async => entitlement;

  @override
  Future<Entitlement> refresh(String token) async => entitlement;
}

/// A store the test drives: it emits purchases through [emit], and records what
/// was bought, restored and acknowledged (completed).
class FakeStore implements Store {
  FakeStore({this.available = true, this.products = const []});

  bool available;
  List<StoreProduct> products;
  final _controller = StreamController<List<StorePurchase>>.broadcast();

  final bought = <StoreProduct>[];
  final completed = <StorePurchase>[];
  bool restoreCalled = false;

  void emit(List<StorePurchase> purchases) => _controller.add(purchases);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> queryProducts(Set<String> ids) async =>
      products.where((p) => ids.contains(p.id)).toList();

  @override
  Stream<List<StorePurchase>> get purchaseStream => _controller.stream;

  @override
  Future<void> buy(StoreProduct product) async => bought.add(product);

  @override
  Future<void> restore() async => restoreCalled = true;

  @override
  Future<void> complete(StorePurchase purchase) async => completed.add(purchase);

  Future<void> dispose() => _controller.close();
}

/// A purchase cloud repository whose grant/restore either return [onGrant] /
/// [onRestore] or, when those are null, throw (standing in for a cloud error).
class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({this.onGrant, this.onRestore});

  final Entitlement Function()? onGrant;
  final Entitlement Function()? onRestore;

  int grantCalls = 0;
  int restoreCalls = 0;
  final grantedOpIds = <String>[];

  @override
  Future<Entitlement> grant({
    required String token,
    required String productId,
    required String payload,
    required String signature,
    required String opId,
  }) async {
    grantCalls++;
    grantedOpIds.add(opId);
    final make = onGrant;
    if (make == null) throw Exception('grant failed');
    return make();
  }

  @override
  Future<Entitlement> restore({
    required String token,
    required List<Map<String, String>> purchases,
  }) async {
    restoreCalls++;
    final make = onRestore;
    if (make == null) throw Exception('restore failed');
    return make();
  }
}
