/// How far along a purchase is, mirrored from the store's purchase stream.
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

/// One purchase as it arrives from the store's stream. [originalJson] is the
/// signed receipt payload and [signature] its RSA-SHA1 signature — the two
/// things `grant_entitlement` / `restore_entitlement` verify. [raw] carries the
/// platform purchase object so it can be acknowledged (completed) after the
/// cloud grants; it is null in tests.
class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    required this.originalJson,
    required this.signature,
    this.raw,
  });

  final String productId;
  final StorePurchaseStatus status;
  final String originalJson;
  final String signature;
  final Object? raw;
}
