import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

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
 * Soft-deletes one notification: { token, id } -> { hidden }.
 *
 * Sets hidden_at so the row leaves the Notification Center (get_notifications
 * filters hidden_at IS NULL) but stays visible to get_pending_reminders, whose
 * WHERE never mentions hidden_at. A hard delete of a row with read = 0 AND
 * was_ignored IS NULL would silently cancel an ignore the user still owes.
 */
export const handler = async (ctx) => {
  const { token, id } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  if (!Number.isInteger(id) || id <= 0) return { hidden: 0 };

  const result = await ctx.appambit.db(
    `UPDATE notifications
        SET hidden_at = CURRENT_TIMESTAMP
      WHERE user_id = ? AND id = ? AND hidden_at IS NULL`,
    [payload.sub, id],
  );

  return { hidden: Number(result.results[0].rows_written ?? 0) };
};
