import { createHmac, timingSafeEqual, createPublicKey, createVerify } from 'node:crypto';

// restore_entitlement — the app reports what the store says is ACTIVE on every
// launch (and from the "Restore purchases" button), because renewals and
// cancellations are invisible to Cloud Code (no outbound HTTP).
//
// Each active, signature-valid purchase re-extends pro_until to at least
// now + RESTORE_GRACE_DAYS, so a still-paying user whose stale purchaseTime
// expiry is already in the past never drops to Free, and a cancelled one lapses
// only a few days after the last launch where the store still reported it.

const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

const column = (row, index, key) => (Array.isArray(row) ? row[index] : row[key]);

const readToken = (ctx, token) => {
  const secret = ctx.secrets?.AUTH_TOKEN_SECRET;
  if (!secret) throw new Error('AUTH_TOKEN_SECRET is not configured');
  if (typeof token !== 'string') return null;

  const parts = token.split('.');
  if (parts.length !== 3) return null;

  const expected = createHmac('sha256', secret)
    .update(`${parts[0]}.${parts[1]}`)
    .digest();
  const actual = Buffer.from(parts[2], 'base64url');
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) return null;

  let payload;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    return null;
  }

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp <= now) return null;

  return payload;
};

const invalidToken = { error: 'INVALID_TOKEN', message: 'Your session has expired. Please log in again.' };
const invalidReceipt = { error: 'INVALID_RECEIPT', message: 'This purchase could not be verified.' };
const wrongPackage = { error: 'WRONG_PACKAGE', message: 'This purchase is not for this app.' };
const ownedByAnother = {
  error: 'PURCHASE_OWNED_BY_ANOTHER_USER',
  message: 'This purchase is already linked to another account.',
};

const ANDROID_PACKAGE = 'com.appambit.unshrimp';
const RESTORE_GRACE_DAYS = 3;

/** True when [signatureB64] is a valid RSA-SHA1 signature of [payload]. */
export const verifyPlaySignature = (publicKeyB64, payload, signatureB64) => {
  if (typeof publicKeyB64 !== 'string' || typeof payload !== 'string' ||
      typeof signatureB64 !== 'string') {
    return false;
  }
  try {
    const key = createPublicKey({
      key: Buffer.from(publicKeyB64, 'base64'),
      format: 'der',
      type: 'spki',
    });
    const verifier = createVerify('RSA-SHA1');
    verifier.update(payload, 'utf8');
    verifier.end();
    return verifier.verify(key, Buffer.from(signatureB64, 'base64'));
  } catch {
    return false;
  }
};

/** Best-effort expiry from the ORIGINAL purchaseTime plus the plan period. */
export const computeExpiry = (productId, purchaseTimeMs) => {
  const base = Number.isFinite(purchaseTimeMs) ? purchaseTimeMs : Date.now();
  const d = new Date(base);
  if (/year|annual/i.test(String(productId))) d.setUTCFullYear(d.getUTCFullYear() + 1);
  else d.setUTCMonth(d.getUTCMonth() + 1);
  return d.toISOString();
};

export const effectiveEntitlement = ({ trialEndsAt, proUntil }, nowMs) => {
  const proActive = typeof proUntil === 'string' && Number.isFinite(Date.parse(proUntil)) && Date.parse(proUntil) > nowMs;
  const trialActive =
    typeof trialEndsAt === 'string' && Number.isFinite(Date.parse(trialEndsAt)) && Date.parse(trialEndsAt) > nowMs;
  const entitlement = proActive ? 'pro' : trialActive ? 'pro_trial' : 'free';
  return { is_pro: proActive || trialActive, entitlement };
};

const loadEntitlement = async (ctx, userId) => {
  const found = await ctx.appambit.db(
    'SELECT trial_ends_at, entitlement, pro_until FROM user_settings WHERE user_id = ?',
    [userId],
  );
  const row = (found.results[0].rows ?? [])[0] ?? {};
  const trialEndsAt = column(row, 0, 'trial_ends_at') ?? null;
  const proUntil = column(row, 2, 'pro_until') ?? null;
  const { is_pro, entitlement } = effectiveEntitlement({ trialEndsAt, proUntil }, Date.now());
  return { is_pro, entitlement, trial_ends_at: trialEndsAt, pro_until: proUntil };
};

const maxIso = (a, b) => (a && b ? (a >= b ? a : b) : a || b);

export const handler = async (ctx) => {
  const { token, store, purchases } = readInput(ctx);
  const claims = readToken(ctx, token);
  if (!claims) return invalidToken;

  // Nothing active reported: do NOT downgrade. pro_until lapses on its own when
  // the cloud clock passes it (get_entitlements computes is_pro on read).
  if (!Array.isArray(purchases) || purchases.length === 0) {
    return loadEntitlement(ctx, claims.sub);
  }

  const nowMs = Date.now();
  const graceFloor = new Date(nowMs + RESTORE_GRACE_DAYS * 86400000).toISOString();

  let candidate = null; // the highest pro_until any active purchase justifies
  const inserts = [];

  for (const entry of purchases) {
    const payload = entry?.payload;
    const signature = entry?.signature;
    const publicKey = ctx.secrets?.PLAY_LICENSE_PUBLIC_KEY;
    if (!publicKey) throw new Error('PLAY_LICENSE_PUBLIC_KEY is not configured');
    if (!verifyPlaySignature(publicKey, payload, signature)) return invalidReceipt;

    let receipt;
    try {
      receipt = JSON.parse(payload);
    } catch {
      return invalidReceipt;
    }
    if (receipt.packageName !== ANDROID_PACKAGE) return wrongPackage;

    const productId = receipt.productId ?? null;
    const purchaseToken = receipt.purchaseToken ?? null;
    const orderId = receipt.orderId ?? null;
    const transactionId = orderId ?? purchaseToken;
    if (!transactionId) return invalidReceipt;

    // A purchase already bound to another account cannot be restored here.
    if (purchaseToken) {
      const owner = await ctx.appambit.db(
        'SELECT user_id FROM purchases WHERE original_transaction_id = ?',
        [purchaseToken],
      );
      const ownerRow = (owner.results[0].rows ?? [])[0];
      if (ownerRow) {
        const ownerId = Number(column(ownerRow, 0, 'user_id'));
        if (Number.isFinite(ownerId) && ownerId !== Number(claims.sub)) return ownedByAnother;
      }
    }

    // Active + valid → it keeps the user Pro for at least the grace window, even
    // if the computed (original-purchaseTime) expiry is already in the past.
    const reach = maxIso(computeExpiry(productId, Number(receipt.purchaseTime)), graceFloor);
    candidate = maxIso(candidate, reach);

    const purchasedAt = Number.isFinite(Number(receipt.purchaseTime))
      ? new Date(Number(receipt.purchaseTime)).toISOString()
      : new Date().toISOString();

    inserts.push({
      sql: `INSERT INTO purchases
              (user_id, store, product_id, transaction_id, original_transaction_id,
               environment, purchased_at, expires_at, raw_payload, status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
            ON CONFLICT(transaction_id) DO NOTHING`,
      params: [
        claims.sub, store ?? 'play', productId, transactionId, purchaseToken,
        'production', purchasedAt, computeExpiry(productId, Number(receipt.purchaseTime)), payload,
      ],
    });
  }

  const setEntitlement = {
    sql: `INSERT INTO user_settings (user_id, entitlement, pro_until)
          VALUES (?, 'pro', ?)
          ON CONFLICT(user_id) DO UPDATE SET
            entitlement = 'pro',
            pro_until = CASE
              WHEN user_settings.pro_until IS NULL OR user_settings.pro_until < excluded.pro_until
                THEN excluded.pro_until
              ELSE user_settings.pro_until
            END`,
    params: [claims.sub, candidate],
  };

  await ctx.appambit.batch([...inserts, setEntitlement], true);

  return loadEntitlement(ctx, claims.sub);
};
