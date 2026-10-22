/// A sellable product as the store describes it: its id and the store's own
/// localized price string (e.g. "$1.99/month"). [raw] carries the platform's
/// product object so a purchase can be started without re-querying; it is null
/// in tests and for non-store platforms.
class StoreProduct {
  const StoreProduct({required this.id, required this.price, this.raw});

  final String id;
  final String price;
  final Object? raw;
}
