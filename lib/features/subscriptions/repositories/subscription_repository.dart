import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cloud/cloud_functions.dart';
import '../models/entitlement.dart';

/// Calls the purchase cloud functions. Both are mutations, so they are called
/// once (never the idempotent-read retry): a timed-out request may already have
/// committed server side.
///
/// A function-level error (INVALID_RECEIPT, PURCHASE_OWNED_BY_ANOTHER_USER,
/// INVALID_TOKEN, …) comes back as `{error}` and is surfaced as a thrown
/// exception by [CloudFunctions]; the caller treats any throw as "not granted".
class SubscriptionRepository {
  const SubscriptionRepository({CloudFunctions cloud = const CloudFunctions()})
    : _cloud = cloud;

  final CloudFunctions _cloud;

  /// Records a single verified purchase and flips the user to paid Pro. [opId]
  /// makes a replay harmless. Returns what the cloud computed (same shape as
  /// `get_entitlements`).
  Future<Entitlement> grant({
    required String token,
    required String productId,
    required String payload,
    required String signature,
    required String opId,
  }) async {
    final data = await _cloud.call('grant_entitlement', {
      'token': token,
      'store': 'play',
      'product_id': productId,
      'payload': payload,
      'signature': signature,
      'op_id': opId,
    });
    return Entitlement.fromJson(data);
  }

  /// Reports the purchases the store says are active and recomputes Pro.
  Future<Entitlement> restore({
    required String token,
    required List<Map<String, String>> purchases,
  }) async {
    final data = await _cloud.call('restore_entitlement', {
      'token': token,
      'store': 'play',
      'purchases': purchases,
    });
    return Entitlement.fromJson(data);
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => const SubscriptionRepository(),
);
