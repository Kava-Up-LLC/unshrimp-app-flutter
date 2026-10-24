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
 * Any timestamp -> the table's convention "YYYY-MM-DD HH:MM:SS" (UTC), the same
 * get_notifications' isoTime expects. Storing a full ISO string with its own Z
 * would make that helper emit a double "ZZ" the client can't parse. Invalid or
 * missing falls back to the server's now.
 */
const normalizeSentAt = (value) => {
  const ms = Date.parse(typeof value === 'string' ? value : '');
  const d = Number.isFinite(ms) ? new Date(ms) : new Date();
  return d.toISOString().slice(0, 19).replace('T', ' ');
};

/**
 * Persists the reminders the device showed since its last sync, one
 * `notifications` row each (kind='reminder'). Called by the app on open, so a
 * reminder shown while the app was closed still lands in the Center.
 *
 * Re-sync safe: a row with the same (user, reminder_key, sent_at, title, body)
 * is that same delivery and is not inserted twice. { token, notifications:
 * [{ title, body, pack, sent_at, reminder_key }] } -> { received }.
 */
export const handler = async (ctx) => {
  const { token, notifications } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const list = Array.isArray(notifications) ? notifications : [];
  if (list.length === 0) return { received: 0 };

  const statements = list.map((n) => {
    const title = typeof n?.title === 'string' ? n.title : null;
    const body = typeof n?.body === 'string' ? n.body : null;
    const pack = typeof n?.pack === 'string' ? n.pack : null;
    const reminderKey = typeof n?.reminder_key === 'string' ? n.reminder_key : null;
    const sentAt = normalizeSentAt(n?.sent_at);
    return {
      sql: `INSERT INTO notifications (user_id, title, body, pack, sent_at, read, kind, reminder_key)
              SELECT ?, ?, ?, ?, ?, 0, 'reminder', ?
               WHERE NOT EXISTS (
                 SELECT 1 FROM notifications
                  WHERE user_id = ? AND kind = 'reminder'
                    AND IFNULL(reminder_key, '') = IFNULL(?, '')
                    AND sent_at = ?
                    AND IFNULL(title, '') = IFNULL(?, '')
                    AND IFNULL(body, '')  = IFNULL(?, '')
               )`,
      params: [
        payload.sub, title, body, pack, sentAt, reminderKey,
        payload.sub, reminderKey, sentAt, title, body,
      ],
    };
  });

  // One atomic transaction; each INSERT is a no-op when that delivery is already
  // stored (the NOT EXISTS), so the whole call is safe to replay. The caller
  // ignores the result, so we just echo how many were received rather than try
  // to count inserts out of the batch's BEGIN/COMMIT-wrapped result.
  await ctx.appambit.batch(statements, true);
  return { received: list.length };
};
