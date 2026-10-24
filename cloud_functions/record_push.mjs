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
 * Stores a push the device received so it also shows in the Notification
 * Center: one `notifications` row with kind='push' and the push's `open` key.
 *
 * "One row per push": the same push can reach the app both in the foreground
 * and as a tap, so a push row with the same title, body and open key on the
 * same calendar day is that one push arriving twice and the second insert is a
 * no-op. kind='push' keeps these rows out of the reminder flow
 * (get_pending_reminders / reconcile_ignored never treat them as a reminder to
 * reconcile). { token, title, body, open } -> { stored }.
 */
export const handler = async (ctx) => {
  const { token, title, body, open } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const titleText = typeof title === 'string' ? title : null;
  const bodyText = typeof body === 'string' ? body : null;
  const openKey = typeof open === 'string' && open.length > 0 ? open : null;

  // sent_at in the table's convention ("YYYY-MM-DD HH:MM:SS" UTC, like every
  // other insert) so get_notifications' isoTime renders it as one ISO instant;
  // storing a full ISO string here produced a double "ZZ" the client can't parse.
  // INSERT ... SELECT ... WHERE NOT EXISTS is the whole dedup: the row is written
  // only when no push with the same (user, title, body, open, day) is there.
  const result = await ctx.appambit.db(
    `INSERT INTO notifications (user_id, title, body, sent_at, read, kind, open)
       SELECT ?, ?, ?, datetime('now'), 0, 'push', ?
        WHERE NOT EXISTS (
          SELECT 1 FROM notifications
           WHERE user_id = ? AND kind = 'push'
             AND IFNULL(title, '') = IFNULL(?, '')
             AND IFNULL(body, '')  = IFNULL(?, '')
             AND IFNULL(open, '')  = IFNULL(?, '')
             AND substr(sent_at, 1, 10) = date('now')
        )`,
    [
      payload.sub, titleText, bodyText, openKey,
      payload.sub, titleText, bodyText, openKey,
    ],
  );

  const written = Number(column(result.results?.[0] ?? {}, 0, 'rows_written') ?? 0);
  return { stored: written > 0 };
};
