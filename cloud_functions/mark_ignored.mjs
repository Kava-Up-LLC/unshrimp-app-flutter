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

export const handler = async (ctx) => {
  const { token, ids } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  // Keep only whole, positive ids; nothing to do when there are none.
  const clean = Array.isArray(ids)
    ? ids.filter((id) => Number.isInteger(id) && id > 0)
    : [];
  if (clean.length === 0) return { marked: 0 };

  // Scoped to this user so one user can never mark another's rows.
  const placeholders = clean.map(() => '?').join(', ');
  const result = await ctx.appambit.db(
    `UPDATE notifications
        SET was_ignored = 1
      WHERE user_id = ? AND id IN (${placeholders})`,
    [payload.sub, ...clean],
  );

  return { marked: Number(result.results[0].rows_written ?? 0) };
};
