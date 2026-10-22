import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

const column = (row, index, key) => (Array.isArray(row) ? row[index] : row[key]);

/** Verifies the HS256 signature and expiry, returning the payload or null. */
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

/**
 * The effective entitlement from the stored timestamps and the cloud's clock.
 * There is no cron in Cloud Code, so the trial "expires when it is read": this
 * is computed from trial_ends_at / pro_until on every call, never from a stored
 * flag that a background job would have to flip. A paid pro_until that is still
 * in the future wins even after the trial is over.
 */
export const effectiveEntitlement = ({ trialEndsAt, proUntil }, nowMs) => {
  const proActive = typeof proUntil === 'string' && Number.isFinite(Date.parse(proUntil)) && Date.parse(proUntil) > nowMs;
  const trialActive =
    typeof trialEndsAt === 'string' && Number.isFinite(Date.parse(trialEndsAt)) && Date.parse(trialEndsAt) > nowMs;
  const entitlement = proActive ? 'pro' : trialActive ? 'pro_trial' : 'free';
  return { is_pro: proActive || trialActive, entitlement };
};

export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  // No settings row yet (a user mid-onboarding) reads as free, never an error:
  // the entitlement read must not be able to end the session.
  const found = await ctx.appambit.db(
    'SELECT trial_ends_at, entitlement, pro_until FROM user_settings WHERE user_id = ?',
    [payload.sub],
  );
  const row = (found.results[0].rows ?? [])[0] ?? {};
  const trialEndsAt = column(row, 0, 'trial_ends_at') ?? null;
  const proUntil = column(row, 2, 'pro_until') ?? null;

  const { is_pro, entitlement } = effectiveEntitlement({ trialEndsAt, proUntil }, Date.now());
  return { is_pro, entitlement, trial_ends_at: trialEndsAt, pro_until: proUntil };
};
