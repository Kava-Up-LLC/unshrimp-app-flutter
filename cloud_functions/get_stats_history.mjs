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

/** The user's local calendar day ("YYYY-MM-DD") for a UTC instant + offset. */
export const localDay = (nowMs, offsetMin) =>
  new Date(nowMs + (Number.isFinite(offsetMin) ? offsetMin : 0) * 60000)
    .toISOString()
    .slice(0, 10);

/** The day `back` days before `day` ("YYYY-MM-DD"), computed in UTC. */
const dayBefore = (day, back) =>
  new Date(Date.parse(`${day}T00:00:00Z`) - back * 86400000).toISOString().slice(0, 10);

/** Mask index for a "YYYY-MM-DD" day: 0=Mon .. 6=Sun, or null if malformed. */
const weekdayIndex = (day) => {
  const ms = Date.parse(`${day}T00:00:00Z`);
  if (Number.isNaN(ms)) return null;
  return (new Date(ms).getUTCDay() + 6) % 7; // JS getUTCDay: 0=Sun -> Mon=0..Sun=6
};

/** True when `day` is a rest day for a 7-char "0/1" Mon..Sun active_days mask. */
const isRestDay = (day, activeDays) => {
  if (typeof activeDays !== 'string' || activeDays.length !== 7) return false;
  const i = weekdayIndex(day);
  return i !== null && activeDays[i] === '0';
};

/** Clamp the requested week count to a sane 1..52, defaulting to 4. */
const weekCount = (weeks) =>
  Number.isInteger(weeks) && weeks > 0 ? Math.min(weeks, 52) : 4;

/**
 * Effective entitlement from the stored timestamps and the cloud clock — the
 * same rule get_entitlements uses (duplicated because each Cloud function is a
 * single self-contained file). A paid pro_until in the future wins even after
 * the trial is over.
 */
const effectiveEntitlement = ({ trialEndsAt, proUntil }, nowMs) => {
  const proActive = typeof proUntil === 'string' && Number.isFinite(Date.parse(proUntil)) && Date.parse(proUntil) > nowMs;
  const trialActive =
    typeof trialEndsAt === 'string' && Number.isFinite(Date.parse(trialEndsAt)) && Date.parse(trialEndsAt) > nowMs;
  return proActive || trialActive;
};

export const handler = async (ctx) => {
  const { token, weeks, tz_offset_min: tzOffsetMin } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  // The daily goal (for the today card), active_days (which weekdays the user
  // works) and the entitlement timestamps: rest days are shown as rest and
  // skipped by the streak; Free users get only today, with the weeks blurred
  // on the client.
  const settingsRow = await ctx.appambit.db(
    'SELECT daily_goal, active_days, trial_ends_at, pro_until FROM user_settings WHERE user_id = ?',
    [payload.sub],
  );
  const settings = (settingsRow.results[0].rows ?? [])[0] ?? {};
  const dailyGoal = Number(column(settings, 0, 'daily_goal') ?? 0);
  const activeDays = column(settings, 1, 'active_days') ?? '1111111';
  const trialEndsAt = column(settings, 2, 'trial_ends_at') ?? null;
  const proUntil = column(settings, 3, 'pro_until') ?? null;

  // Full history is a Pro feature; Free sees only today.
  const isPro = effectiveEntitlement({ trialEndsAt, proUntil }, Date.now());
  const n = isPro ? weekCount(weeks) : 1;
  const totalDays = isPro ? n * 7 : 1;
  const today = localDay(Date.now(), tzOffsetMin);
  const start = dayBefore(today, totalDays - 1);

  const found = await ctx.appambit.db(
    `SELECT day, breaks, ignored, goal_met
       FROM user_daily_stats
      WHERE user_id = ? AND day >= ? AND day <= ?`,
    [payload.sub, start, today],
  );
  const stored = new Map();
  for (const row of found.results[0].rows ?? []) {
    stored.set(column(row, 0, 'day'), {
      breaks: Number(column(row, 1, 'breaks') ?? 0),
      ignored: Number(column(row, 2, 'ignored') ?? 0),
      goal_met: Number(column(row, 3, 'goal_met') ?? 0) ? 1 : 0,
    });
  }

  // One entry per day, oldest -> newest, zeros for days with no stored row. A
  // rest day is flagged and skipped by the streak: it neither breaks nor
  // extends the run, so a met day before and after bridge across it.
  const days = [];
  let bestStreak = 0;
  let run = 0;
  let goalMetDays = 0;
  for (let i = totalDays - 1; i >= 0; i -= 1) {
    const day = dayBefore(today, i);
    const rest = isRestDay(day, activeDays);
    const row = stored.get(day) ?? { breaks: 0, ignored: 0, goal_met: 0 };
    days.push({ day, ...row, rest: rest ? 1 : 0 });
    if (rest) continue;
    if (row.goal_met) {
      run += 1;
      goalMetDays += 1;
      if (run > bestStreak) bestStreak = run;
    } else {
      run = 0;
    }
  }

  return {
    weeks: n,
    is_pro: isPro,
    daily_goal: dailyGoal,
    best_streak: bestStreak,
    goal_met_days: goalMetDays,
    days,
  };
};
