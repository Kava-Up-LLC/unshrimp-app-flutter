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

/** The user's local calendar day ("YYYY-MM-DD") for a UTC instant + offset.
 *  user_daily_stats is keyed by the user's local day, the same one
 *  get_stats_history reads, so Home and History agree on "today". */
export const localDay = (nowMs, offsetMin) =>
  new Date(nowMs + (Number.isFinite(offsetMin) ? offsetMin : 0) * 60000)
    .toISOString()
    .slice(0, 10);

// ---- Shared idempotency helper -- INLINED from cloud_functions/_applied_ops.mjs.
// Deploys are a single file with no imports, so this is copied, not imported.
// Keep in sync with that canonical source. See it for the full contract and the
// episode-6 grant_entitlement note.
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
  const { token, op_id: opId, tz_offset_min: tzOffsetMin } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  // The History screen reads per-day rows; a break adds one to today's row (the
  // user's local day) and flips goal_met once the day's breaks reach the goal.
  const today = localDay(Date.now(), tzOffsetMin);
  const dailyStats = {
    sql: `INSERT INTO user_daily_stats (user_id, day, breaks, ignored, goal_met)
            VALUES (?, ?, 1, 0,
              CASE WHEN 1 >= (SELECT daily_goal FROM user_settings WHERE user_id = ?)
                THEN 1 ELSE 0 END)
          ON CONFLICT(user_id, day) DO UPDATE SET
            breaks = breaks + 1,
            goal_met = CASE
              WHEN breaks + 1 >= (SELECT daily_goal FROM user_settings WHERE user_id = ?)
                THEN 1
              ELSE goal_met
            END`,
    params: [payload.sub, today, payload.sub, payload.sub],
  };

  // One atomic read-modify-write. Every right-hand reference reads the OLD
  // row, so a second call the same day sees last_break_date = today and does
  // NOT bump current_streak again (the double-call guard). "today" is the UTC
  // date — the streak boundary, unlike the reminder window, stays server-side.
  // roast_pending is cleared in the SAME transaction that moves the counters.
  const mutation = {
    sql: `UPDATE user_stats
             SET ignored_count = 0,
                 roast_level = MAX(0, roast_level - 1),
                 breaks_today = CASE
                   WHEN last_break_date IS NULL OR last_break_date < date('now')
                     THEN 1
                   ELSE breaks_today + 1
                 END,
                 current_streak = CASE
                   WHEN (CASE
                           WHEN last_break_date IS NULL OR last_break_date < date('now')
                             THEN 1
                           ELSE breaks_today + 1
                         END) >= (SELECT daily_goal FROM user_settings WHERE user_id = ?)
                    AND (last_break_date IS NULL OR last_break_date <> date('now'))
                     THEN current_streak + 1
                   ELSE current_streak
                 END,
                 last_break_date = date('now'),
                 roast_pending = 0
           WHERE user_id = ?`,
    params: [payload.sub, payload.sub],
  };

  // op_id makes a replayed flush harmless: the second apply rolls back and the
  // row does not move. A legacy client without an op_id applies unguarded.
  await applyOnce(ctx, {
    opId,
    userId: payload.sub,
    fn: 'register_break',
    statements: [mutation, dailyStats],
  });

  const stats = await loadStats(ctx, payload.sub);
  return stats ?? invalidToken;
};
