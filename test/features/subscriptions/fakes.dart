import 'package:unshrimp_app/features/subscriptions/models/entitlement.dart';
import 'package:unshrimp_app/features/subscriptions/repositories/entitlement_repository.dart';

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
