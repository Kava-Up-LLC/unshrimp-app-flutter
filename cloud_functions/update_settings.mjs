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
  daily_goal, roast_threshold, pain_zone, quiet_mode, paused_until, active_days`;

const noSettings = { error: 'NO_SETTINGS', message: 'Finish onboarding to set up your reminders.' };

// Tone is stored as roast_threshold (the mapping save_onboarding uses); the two
// are a strict bijection, so tone is derived from the threshold on read.
const ROAST_THRESHOLD_BY_TONE = { gentle: 5, direct: 3, no_mercy: 2 };
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
    active_days: column(row, 10, 'active_days') ?? '1111111',
  };
};

const invalidSettings = (message) => ({ error: 'INVALID_SETTINGS', message });

// The same interval options onboarding can seed (PLAN 1.4.1).
const INTERVALS = [30, 45, 60, 90];
const MIN_GOAL = 1;
const MAX_GOAL = 12;

/** Minutes since midnight for "HH:mm", or null when malformed. */
const toMinutes = (time) => {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(typeof time === 'string' ? time : '');
  return match ? Number(match[1]) * 60 + Number(match[2]) : null;
};

export const handler = async (ctx) => {
  const { token, settings } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const current = await loadSettings(ctx, payload.sub);
  if (!current) return noSettings;

  // Only these fields can be changed; anything else in `settings` is ignored.
  const input = settings !== null && typeof settings === 'object' ? settings : {};
  const changes = {};

  if ('active_start' in input || 'active_end' in input) {
    const start = input.active_start ?? current.active_start;
    const end = input.active_end ?? current.active_end;
    const startMin = toMinutes(start);
    const endMin = toMinutes(end);
    if (startMin === null || endMin === null) return invalidSettings('Use HH:mm for your active hours.');
    if (endMin <= startMin) return invalidSettings('Your active hours must end after they start.');
    changes.active_start = start;
    changes.active_end = end;
  }

  if ('reminder_interval_min' in input) {
    const interval = input.reminder_interval_min;
    if (!INTERVALS.includes(interval)) {
      return invalidSettings(`Pick a reminder interval of ${INTERVALS.join(', ')} minutes.`);
    }
    changes.reminder_interval_min = interval;
    // You have until the next reminder to respond (PLAN 1.4).
    changes.grace_window_min = interval;
  }

  if ('daily_goal' in input) {
    const goal = input.daily_goal;
    if (!Number.isInteger(goal) || goal < MIN_GOAL || goal > MAX_GOAL) {
      return invalidSettings(`Pick a daily goal between ${MIN_GOAL} and ${MAX_GOAL} breaks.`);
    }
    changes.daily_goal = goal;
  }

  // Tone drives roast_threshold server-side; the client never sends the number.
  if ('tone' in input) {
    const threshold = ROAST_THRESHOLD_BY_TONE[input.tone];
    if (!threshold) return invalidSettings('Pick how the app should treat you.');
    changes.roast_threshold = threshold;
  }

  if ('quiet_mode' in input) {
    if (typeof input.quiet_mode !== 'boolean') return invalidSettings('Quiet mode must be on or off.');
    changes.quiet_mode = input.quiet_mode ? 1 : 0;
  }

  if ('paused_until' in input) {
    const until = input.paused_until;
    if (until === null) {
      changes.paused_until = null;
    } else {
      const date = typeof until === 'string' ? new Date(until) : null;
      if (!date || Number.isNaN(date.getTime())) return invalidSettings('Pick when to resume reminders.');
      if (date.getTime() <= Date.now()) return invalidSettings('Pick a pause that ends in the future.');
      changes.paused_until = date.toISOString();
    }
  }

  // Which weekdays the user works, "0/1" x7 (Mon..Sun). At least one work day.
  if ('active_days' in input) {
    const days = input.active_days;
    if (typeof days !== 'string' || !/^[01]{7}$/.test(days) || !days.includes('1')) {
      return invalidSettings('Pick at least one work day.');
    }
    changes.active_days = days;
  }

  const columns = Object.keys(changes);
  if (columns.length === 0) return invalidSettings('Nothing to update.');

  // Column names come from the allowlist above, never from the request.
  await ctx.appambit.db(
    `UPDATE user_settings
        SET ${columns.map((name) => `${name} = ?`).join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = ?`,
    [...columns.map((name) => changes[name]), current.user_id],
  );

  return loadSettings(ctx, current.user_id);
};
