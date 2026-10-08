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

const LIMIT = 100;

/** `YYYY-MM-DD HH:MM:SS` (UTC) -> ISO 8601 with Z. */
const isoTime = (value) => (value ? `${String(value).replace(' ', 'T')}Z` : null);

const flag = (value) => (value === null || value === undefined ? null : Boolean(Number(value)));

/** The user's notifications, newest first: { token } -> { notifications: [...] }. */
export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const found = await ctx.appambit.db(
    `SELECT id, title, body, pack, sent_at, read, was_ignored, reminder_key
       FROM notifications
      WHERE user_id = ? AND hidden_at IS NULL
      ORDER BY sent_at DESC, id DESC
      LIMIT ${LIMIT}`,
    [payload.sub],
  );

  return {
    notifications: (found.results[0].rows ?? []).map((row) => ({
      id: Number(column(row, 0, 'id')),
      title: column(row, 1, 'title'),
      body: column(row, 2, 'body'),
      pack: column(row, 3, 'pack'),
      sent_at: isoTime(column(row, 4, 'sent_at')),
      read: Boolean(Number(column(row, 5, 'read'))),
      was_ignored: flag(column(row, 6, 'was_ignored')),
      reminder_key: column(row, 7, 'reminder_key') ?? null,
    })),
  };
};
