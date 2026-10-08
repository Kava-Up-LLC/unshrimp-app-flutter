import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

/** Reads a column by position (INSERT ... RETURNING rows) or by name. */
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

// ---- Active-window helpers (pure, exported for unit tests) -----------------
//
// active_start/active_end are the user's wall clock ("HH:mm") with no stored
// timezone, so the app sends tz_offset_min (DateTime.now().timeZoneOffset in
// minutes, e.g. -360 for UTC-6). We convert server UTC to the user's local
// minute-of-day before comparing. Missing offset defaults to UTC (0).

/** Minutes since midnight for "HH:mm", or null when malformed. */
export const toMinutes = (time) => {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(typeof time === 'string' ? time : '');
  return match ? Number(match[1]) * 60 + Number(match[2]) : null;
};

/** The user's local minute-of-day (0..1439) for a UTC instant + offset. */
export const localMinuteOfDay = (nowMs, offsetMin) => {
  const localEpochMin = Math.floor(nowMs / 60000) + offsetMin;
  return ((localEpochMin % 1440) + 1440) % 1440;
};

/**
 * True when the user's local time is inside [start, end). update_settings
 * guarantees end > start (no overnight windows). Malformed bounds => false.
 */
export const isWithinWindow = (nowMs, offsetMin, start, end) => {
  const startMin = toMinutes(start);
  const endMin = toMinutes(end);
  if (startMin === null || endMin === null) return false;
  const current = localMinuteOfDay(nowMs, offsetMin);
  return current >= startMin && current < endMin;
};

/** Reads the window/threshold fields needed to gate and apply an ignore. */
const loadSettings = async (ctx, userId) => {
  const found = await ctx.appambit.db(
    `SELECT active_start, active_end, roast_threshold, paused_until
       FROM user_settings WHERE user_id = ?`,
    [userId],
  );
  const row = (found.results[0].rows ?? [])[0];
  if (!row) return null;
  return {
    active_start: column(row, 0, 'active_start'),
    active_end: column(row, 1, 'active_end'),
    roast_threshold: Number(column(row, 2, 'roast_threshold')),
    paused_until: column(row, 3, 'paused_until') ?? null,
  };
};

/** Reads the user's stats row in the exact shape get_user_stats returns. */
const loadStats = async (ctx, userId) => {
  const found = await ctx.appambit.db(
    `SELECT u.id, u.name, s.archetype, s.current_streak, s.breaks_today,
            s.ignored_count, s.roast_level, s.roast_pending
       FROM users u
       LEFT JOIN user_stats s ON s.user_id = u.id
      WHERE u.id = ?`,
    [userId],
  );
  const row = (found.results[0].rows ?? [])[0];
  if (!row) return null;

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
  };
};

export const handler = async (ctx) => {
  const { token, ids, tz_offset_min: tzOffsetMin } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const stats = await loadStats(ctx, payload.sub);
  if (!stats) return invalidToken;

  // Keep only whole, positive ids; nothing to reconcile when there are none.
  const clean = Array.isArray(ids)
    ? ids.filter((id) => Number.isInteger(id) && id > 0)
    : [];
  if (clean.length === 0) return { ...stats, counted: 0, ignored: 0 };

  // Same active-window / paused gate as register_ignore: outside the window or
  // paused, an ignore is not counted and the rows are left pending.
  const settings = await loadSettings(ctx, payload.sub);
  const offsetMin = Number.isFinite(tzOffsetMin) ? tzOffsetMin : 0;
  const paused =
    settings?.paused_until != null &&
    new Date(settings.paused_until).getTime() > Date.now();
  const inWindow =
    settings != null &&
    isWithinWindow(Date.now(), offsetMin, settings.active_start, settings.active_end);
  if (!inWindow || paused) return { ...stats, counted: 0, ignored: 0 };

  const placeholders = clean.map(() => '?').join(', ');
  // The count of still-pending rows among the given ids. Evaluated inside the
  // same transaction, BEFORE the rows are marked, so the stat update and the
  // mark agree on the same N. A repeated call finds those rows already marked,
  // so N is 0 and both statements are a no-op — the whole call is idempotent,
  // which is what makes the old register_ignore/mark_ignored double-count
  // (app dies, is backgrounded or loses the network between the two) impossible.
  const pendingCount = `(SELECT COUNT(*) FROM notifications
                           WHERE user_id = ? AND was_ignored IS NULL
                             AND id IN (${placeholders}))`;
  await ctx.appambit.batch(
    [
      {
        sql: `UPDATE user_stats
                 SET ignored_count = ignored_count + ${pendingCount},
                     roast_level = MIN(5, roast_level + ${pendingCount}),
                     roast_pending = CASE
                       WHEN ignored_count + ${pendingCount} >= ? THEN 1
                       ELSE roast_pending
                     END
               WHERE user_id = ?`,
        params: [
          payload.sub, ...clean,
          payload.sub, ...clean,
          payload.sub, ...clean,
          settings.roast_threshold,
          payload.sub,
        ],
      },
      {
        sql: `UPDATE notifications
                 SET was_ignored = 1
               WHERE user_id = ? AND was_ignored IS NULL AND id IN (${placeholders})`,
        params: [payload.sub, ...clean],
      },
    ],
    true,
  );

  const updated = (await loadStats(ctx, payload.sub)) ?? stats;
  const counted = updated.ignored_count - stats.ignored_count;
  return { ...updated, counted, ignored: counted };
};
