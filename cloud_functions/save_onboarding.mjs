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
const invalidAnswers = (message) => ({ error: 'INVALID_ANSWERS', message });

// Deterministic map from PLAN 1.4.1: onboarding answers -> user_settings.
const INTERVAL_BY_SITTING = { '0-4': 90, '4-8': 60, '8-12': 45, '12+': 30 };
const ARCHETYPE_BY_SITTING = {
  '0-4': 'Shrimp in Training',
  '4-8': 'Office Shrimp',
  '8-12': 'Hardened Shrimp',
  '12+': 'Fossilized Shrimp',
};
const ROAST_THRESHOLD_BY_TONE = { gentle: 5, direct: 3, no_mercy: 2 };
const PAIN_ZONES = ['neck', 'shoulders', 'lower_back', 'wrists', 'none'];
const DEFAULT_START = '09:00';
const DEFAULT_END = '18:00';

/** Minutes since midnight for "HH:mm", or null when malformed. */
const toMinutes = (time) => {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time ?? '');
  return match ? Number(match[1]) * 60 + Number(match[2]) : null;
};

const clamp = (value, min, max) => Math.min(Math.max(value, min), max);

export const handler = async (ctx) => {
  const { token, answers } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const found = await ctx.appambit.db('SELECT id FROM users WHERE id = ?', [payload.sub]);
  const user = (found.results[0].rows ?? [])[0];
  // The token outlived its user.
  if (!user) return invalidToken;
  const userId = Number(column(user, 0, 'id'));

  const input = answers ?? {};
  const interval = INTERVAL_BY_SITTING[input.sitting_hours];
  if (!interval) return invalidAnswers('Pick how many hours a day you sit.');
  const roastThreshold = ROAST_THRESHOLD_BY_TONE[input.tone];
  if (!roastThreshold) return invalidAnswers('Pick how the app should treat you.');
  if (!PAIN_ZONES.includes(input.pain_zone)) return invalidAnswers('Pick where it hurts most.');

  const activeStart = input.active_start ?? DEFAULT_START;
  const activeEnd = input.active_end ?? DEFAULT_END;
  const startMin = toMinutes(activeStart);
  const endMin = toMinutes(activeEnd);
  if (startMin === null || endMin === null) return invalidAnswers('Use HH:mm for your work hours.');
  if (endMin <= startMin) return invalidAnswers('Your work hours must end after they start.');

  // Math.round rounds .5 up, as PLAN 1.4.1 requires.
  const dailyGoal = clamp(Math.round(((endMin - startMin) / interval) * 0.5), 3, 6);
  const archetype = ARCHETYPE_BY_SITTING[input.sitting_hours];

  await ctx.appambit.batch(
    [
      {
        // Re-running onboarding replaces the user's settings, never duplicates them.
        sql: `INSERT INTO user_settings (user_id, active_start, active_end, reminder_interval_min,
                grace_window_min, daily_goal, roast_threshold, pain_zone, quiet_mode, paused_until, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, CURRENT_TIMESTAMP)
              ON CONFLICT(user_id) DO UPDATE SET
                active_start = excluded.active_start,
                active_end = excluded.active_end,
                reminder_interval_min = excluded.reminder_interval_min,
                grace_window_min = excluded.grace_window_min,
                daily_goal = excluded.daily_goal,
                roast_threshold = excluded.roast_threshold,
                pain_zone = excluded.pain_zone,
                quiet_mode = 0,
                paused_until = NULL,
                updated_at = CURRENT_TIMESTAMP`,
        params: [userId, activeStart, activeEnd, interval, interval, dailyGoal, roastThreshold, input.pain_zone],
      },
      { sql: 'UPDATE user_stats SET archetype = ? WHERE user_id = ?', params: [archetype, userId] },
      {
        // A user gets a stats row at signup; create it if it ever went missing.
        sql: `INSERT INTO user_stats (user_id, archetype, current_streak, breaks_today,
                ignored_count, roast_level, roast_pending)
              SELECT ?, ?, 0, 0, 0, 0, 0
               WHERE NOT EXISTS (SELECT 1 FROM user_stats WHERE user_id = ?)`,
        params: [userId, archetype, userId],
      },
    ],
    true,
  );

  const seeded = await ctx.appambit.db(
    `SELECT user_id, active_start, active_end, reminder_interval_min, grace_window_min,
            daily_goal, roast_threshold, pain_zone, quiet_mode, paused_until
       FROM user_settings WHERE user_id = ?`,
    [userId],
  );
  const row = seeded.results[0].rows[0];

  return {
    user_id: Number(column(row, 0, 'user_id')),
    active_start: column(row, 1, 'active_start'),
    active_end: column(row, 2, 'active_end'),
    reminder_interval_min: Number(column(row, 3, 'reminder_interval_min')),
    grace_window_min: Number(column(row, 4, 'grace_window_min')),
    daily_goal: Number(column(row, 5, 'daily_goal')),
    roast_threshold: Number(column(row, 6, 'roast_threshold')),
    pain_zone: column(row, 7, 'pain_zone'),
    quiet_mode: Boolean(Number(column(row, 8, 'quiet_mode'))),
    paused_until: column(row, 9, 'paused_until') ?? null,
    archetype,
  };
};
