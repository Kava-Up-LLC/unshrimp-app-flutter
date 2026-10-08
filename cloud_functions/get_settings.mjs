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

const SETTINGS_COLUMNS = `user_id, active_start, active_end, reminder_interval_min, grace_window_min,
  daily_goal, roast_threshold, pain_zone, quiet_mode, paused_until`;

const noSettings = { error: 'NO_SETTINGS', message: 'Finish onboarding to set up your reminders.' };

// Tone is derived from roast_threshold (the mapping save_onboarding uses).
const TONE_BY_THRESHOLD = { 5: 'gentle', 3: 'direct', 2: 'no_mercy' };

/** Reads the user's user_settings row as a plain object, or null. */
const loadSettings = async (ctx, userId) => {
  const found = await ctx.appambit.db(
    `SELECT ${SETTINGS_COLUMNS} FROM user_settings WHERE user_id = ?`,
    [userId],
  );
  const row = (found.results[0].rows ?? [])[0];
  if (!row) return null;
  const roastThreshold = Number(column(row, 6, 'roast_threshold'));
  return {
    user_id: Number(column(row, 0, 'user_id')),
    active_start: column(row, 1, 'active_start'),
    active_end: column(row, 2, 'active_end'),
    reminder_interval_min: Number(column(row, 3, 'reminder_interval_min')),
    grace_window_min: Number(column(row, 4, 'grace_window_min')),
    daily_goal: Number(column(row, 5, 'daily_goal')),
    roast_threshold: roastThreshold,
    tone: TONE_BY_THRESHOLD[roastThreshold] ?? 'direct',
    pain_zone: column(row, 7, 'pain_zone'),
    quiet_mode: Boolean(Number(column(row, 8, 'quiet_mode'))),
    paused_until: column(row, 9, 'paused_until') ?? null,
  };
};

export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const settings = await loadSettings(ctx, payload.sub);
  return settings ?? noSettings;
};
