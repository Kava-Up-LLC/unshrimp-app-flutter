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

export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const found = await ctx.appambit.db(
    `SELECT u.id, u.name, s.archetype, s.current_streak, s.breaks_today,
            s.ignored_count, s.roast_level, s.roast_pending, st.daily_goal
       FROM users u
       LEFT JOIN user_stats s ON s.user_id = u.id
       LEFT JOIN user_settings st ON st.user_id = u.id
      WHERE u.id = ?`,
    [payload.sub],
  );
  const row = (found.results[0].rows ?? [])[0];
  // The token outlived its user.
  if (!row) return invalidToken;

  // A user always gets a stats row at signup, but LEFT JOIN keeps Home
  // working (at zero) rather than failing if that row ever goes missing.
  const counter = (index, key) => Number(column(row, index, key) ?? 0);

  return {
    user_id: Number(column(row, 0, 'id')),
    name: column(row, 1, 'name'),
    archetype: column(row, 2, 'archetype') ?? null,
    current_streak: counter(3, 'current_streak'),
    breaks_today: counter(4, 'breaks_today'),
    ignored_count: counter(5, 'ignored_count'),
    roast_level: counter(6, 'roast_level'),
    roast_pending: Boolean(counter(7, 'roast_pending')),
    daily_goal: counter(8, 'daily_goal'),
  };
};
