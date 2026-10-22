import { createHmac, timingSafeEqual, createPublicKey, createVerify } from 'node:crypto';

// grant_entitlement — records a verified Play purchase and flips the user to
// paid Pro. Cloud Code has no outbound HTTP, so it CANNOT call the Google Play
// Developer API: it trusts only the signed receipt the app already holds.
//
// ⚠️ Renewals and cancellations are NOT visible to the cloud. A subscription's
// purchaseTime is the ORIGINAL purchase, so the expiry computed here goes stale
// after the first renewal. The app therefore reports what the store says is
// active on EVERY launch (restore_entitlement), which re-extends pro_until.

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

const column = (row, index, key) => (Array.isArray(row) ? row[index] : row[key]);

/** Verifies the HS256 session token and expiry, returning the payload or null. */
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
const missingOpId = { error: 'MISSING_OP_ID', message: 'A purchase must carry an op_id.' };
const wrongPackage = { error: 'WRONG_PACKAGE', message: 'This purchase is not for this app.' };

/** The one Android app id a receipt is allowed to name. */
const ANDROID_PACKAGE = 'com.appambit.unshrimp';

// ---- Play receipt verification ----------------------------------------------
// Each Play purchase ships with the original JSON (INAPP/SUBS data) and an
// RSA-SHA1 signature made with the app's license key. The license PUBLIC key
// from Play Console is base64-encoded X.509 SubjectPublicKeyInfo (SPKI) DER.

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

/**
 * Best-effort expiry for a subscription from the ORIGINAL purchaseTime plus the
 * plan period (monthly → +1 month, yearly → +1 year). Goes stale after the
 * first renewal — restore_entitlement re-extends it on every launch.
 */
export const computeExpiry = (productId, purchaseTimeMs) => {
  const base = Number.isFinite(purchaseTimeMs) ? purchaseTimeMs : Date.now();
  const d = new Date(base);
  if (/year|annual/i.test(String(productId))) d.setUTCFullYear(d.getUTCFullYear() + 1);
  else d.setUTCMonth(d.getUTCMonth() + 1);
  return d.toISOString();
};

/**
 * The effective entitlement from the stored timestamps and the cloud's clock.
 * Copied from get_entitlements so grant/restore return the identical object.
 */
export const effectiveEntitlement = ({ trialEndsAt, proUntil }, nowMs) => {
  const proActive = typeof proUntil === 'string' && Number.isFinite(Date.parse(proUntil)) && Date.parse(proUntil) > nowMs;
  const trialActive =
    typeof trialEndsAt === 'string' && Number.isFinite(Date.parse(trialEndsAt)) && Date.parse(trialEndsAt) > nowMs;
  const entitlement = proActive ? 'pro' : trialActive ? 'pro_trial' : 'free';
  return { is_pro: proActive || trialActive, entitlement };
};

// ---- Shared idempotency helper -- INLINED from cloud_functions/_applied_ops.mjs.
// grant_entitlement MUST reject a missing op_id (a double-applied purchase is a
// real problem), so the unguarded fallback below is never reached here.
const applyOnce = async (ctx, { opId, userId, fn, statements }) => {
  if (typeof opId !== 'string' || opId.length === 0) {
    await ctx.appambit.batch(statements, true);
    return { applied: true };
  }
  try {
    await ctx.appambit.batch(
      [
        {
          sql: `INSERT INTO applied_ops (op_id, user_id, function, applied_at)
                 VALUES (?, ?, ?, datetime('now'))`,
          params: [opId, userId, fn],
        },
        ...statements,
      ],
      true,
    );
    return { applied: true };
  } catch (err) {
    const seen = await ctx.appambit.db(
      'SELECT 1 FROM applied_ops WHERE op_id = ?',
      [opId],
    );
    if ((seen.results[0].rows ?? []).length === 0) throw err; // genuine failure
    return { applied: false }; // replay: rolled back, nothing changed
  }
};

/** Reads the user's entitlement in the exact shape get_entitlements returns. */
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

export const handler = async (ctx) => {
  const { token, store, payload, signature, op_id: opId } = readInput(ctx);
  const claims = readToken(ctx, token);
  if (!claims) return invalidToken;

  // A replayed grant must never double-apply, so op_id is required here.
  if (typeof opId !== 'string' || opId.length === 0) return missingOpId;

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
  // Test purchases may not carry an orderId, so fall back to the purchaseToken.
  const transactionId = orderId ?? purchaseToken;
  if (!transactionId) return invalidReceipt;
  const expiresAt = computeExpiry(productId, Number(receipt.purchaseTime));
  const purchasedAt = Number.isFinite(Number(receipt.purchaseTime))
    ? new Date(Number(receipt.purchaseTime)).toISOString()
    : new Date().toISOString();

  const insertPurchase = {
    sql: `INSERT INTO purchases
            (user_id, store, product_id, transaction_id, original_transaction_id,
             environment, purchased_at, expires_at, raw_payload, status)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
          ON CONFLICT(transaction_id) DO NOTHING`,
    params: [
      claims.sub, store ?? 'play', productId, transactionId, purchaseToken,
      'production', purchasedAt, expiresAt, payload,
    ],
  };

  // Set paid Pro and extend pro_until, never shrink it. UPSERT so a user whose
  // settings row does not exist yet still becomes Pro.
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
    params: [claims.sub, expiresAt],
  };

  await applyOnce(ctx, {
    opId,
    userId: claims.sub,
    fn: 'grant_entitlement',
    statements: [insertPurchase, setEntitlement],
  });

  return loadEntitlement(ctx, claims.sub);
};
