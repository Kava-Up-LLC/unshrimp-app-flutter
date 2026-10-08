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

/** "YYYY-MM-DD HH:MM:SS" (stored UTC) -> ISO-8601 UTC so the device parses it
 *  as an instant, not as local time. Leaves an already-ISO value untouched. */
const toIsoUtc = (value) => {
  const raw = value == null ? '' : String(value);
  if (raw === '' || raw.includes('T')) return raw;
  return `${raw.replace(' ', 'T')}Z`;
};

export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const found = await ctx.appambit.db(
    `SELECT id, reminder_key, sent_at
       FROM notifications
      WHERE user_id = ? AND read = 0 AND was_ignored IS NULL
      ORDER BY sent_at ASC`,
    [payload.sub],
  );

  const rows = found.results[0].rows ?? [];
  const reminders = rows.map((row) => ({
    id: Number(column(row, 0, 'id')),
    reminder_key: column(row, 1, 'reminder_key') ?? null,
    sent_at: toIsoUtc(column(row, 2, 'sent_at')),
  }));

  return { reminders };
};
