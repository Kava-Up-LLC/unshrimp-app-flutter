/// The outcome of one Subscribe tap, from the app's point of view.
///
/// `purchased` means the store charged the user AND `grant_entitlement` answered
/// OK (only then is the purchase acknowledged). `failed` covers a store error or
/// a cloud grant that did not succeed — the purchase is left unacknowledged so
/// the store redelivers it. `cancelled` is the user backing out of the sheet.
enum PurchaseResult { purchased, cancelled, failed }
