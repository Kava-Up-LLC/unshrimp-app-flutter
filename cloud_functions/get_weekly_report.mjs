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

/** The day `n` days from `day` ("YYYY-MM-DD"); negative `n` goes back. */
const addDays = (day, n) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);

/** Mask index for a "YYYY-MM-DD" day: 0=Mon .. 6=Sun. */
const weekdayIndex = (day) => (new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7;

/**
 * Effective Pro from the stored timestamps and the cloud clock — the same rule
 * get_entitlements uses, inlined because each Cloud function is a single
 * self-contained file. A paid pro_until in the future wins even after the trial
 * is over (the demo confirms a purchase by setting pro_until).
 */
const effectiveEntitlement = ({ trialEndsAt, proUntil }, nowMs) => {
  const proActive = typeof proUntil === 'string' && Number.isFinite(Date.parse(proUntil)) && Date.parse(proUntil) > nowMs;
  const trialActive =
    typeof trialEndsAt === 'string' && Number.isFinite(Date.parse(trialEndsAt)) && Date.parse(trialEndsAt) > nowMs;
  return proActive || trialActive;
};

/** Sum/best-day/longest-streak for the 7 days Mon..Sun starting at `weekStart`. */
const summarize = (stored, weekStart) => {
  let breaks = 0;
  let ignored = 0;
  let bestDay = null;
  let bestBreaks = -1;
  let longest = 0;
  let run = 0;
  for (let i = 0; i < 7; i += 1) {
    const row = stored.get(addDays(weekStart, i)) ?? { breaks: 0, ignored: 0, goal_met: 0 };
    breaks += row.breaks;
    ignored += row.ignored;
    if (row.breaks > bestBreaks) {
      bestBreaks = row.breaks;
      bestDay = addDays(weekStart, i);
    }
    if (row.goal_met) {
      run += 1;
      if (run > longest) longest = run;
    } else {
      run = 0;
    }
  }
  // A week with no breaks has no meaningful best day.
  return { breaks, ignored, bestDay: bestBreaks > 0 ? bestDay : null, longest };
};

/**
 * The verdict is the lowest-rank row whose conditions the week meets: a null
 * min_breaks / max_ignored always matches, so the no-condition row is the
 * guaranteed fallback. {ignored} in the chosen text is replaced with the count.
 * Read live on every call, so a dashboard edit shows on the next open with no
 * release.
 */
const pickVerdict = (rows, { breaks, ignored }) => {
  for (const row of rows) {
    const minBreaks = column(row, 1, 'min_breaks');
    const maxIgnored = column(row, 2, 'max_ignored');
    const breaksOk = minBreaks == null || breaks >= Number(minBreaks);
    const ignoredOk = maxIgnored == null || ignored <= Number(maxIgnored);
    if (breaksOk && ignoredOk) {
      return String(column(row, 3, 'text') ?? '').replace(/\{ignored\}/g, String(ignored));
    }
  }
  return null;
};

export const handler = async (ctx) => {
  const { token, tz_offset_min: tzOffsetMin } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const settingsRow = await ctx.appambit.db(
    'SELECT trial_ends_at, pro_until FROM user_settings WHERE user_id = ?',
    [payload.sub],
  );
  const settings = (settingsRow.results[0].rows ?? [])[0] ?? {};
  const trialEndsAt = column(settings, 0, 'trial_ends_at') ?? null;
  const proUntil = column(settings, 1, 'pro_until') ?? null;

  // The weekly Spine Report is Pro-only; Free gets a locked stub it blurs.
  if (!effectiveEntitlement({ trialEndsAt, proUntil }, Date.now())) return { locked: true };

  // Last complete week, Monday..Sunday in the user's local time, and the week
  // before it for the delta.
  const today = localDay(Date.now(), tzOffsetMin);
  const thisMonday = addDays(today, -weekdayIndex(today));
  const weekStart = addDays(thisMonday, -7); // Monday of the last complete week
  const priorStart = addDays(weekStart, -7);
  const lastSunday = addDays(thisMonday, -1);

  const found = await ctx.appambit.db(
    `SELECT day, breaks, ignored, goal_met
       FROM user_daily_stats
      WHERE user_id = ? AND day >= ? AND day <= ?`,
    [payload.sub, priorStart, lastSunday],
  );
  const stored = new Map();
  for (const row of found.results[0].rows ?? []) {
    stored.set(column(row, 0, 'day'), {
      breaks: Number(column(row, 1, 'breaks') ?? 0),
      ignored: Number(column(row, 2, 'ignored') ?? 0),
      goal_met: Number(column(row, 3, 'goal_met') ?? 0) ? 1 : 0,
    });
  }

  const week = summarize(stored, weekStart);
  const prior = summarize(stored, priorStart);

  const verdicts = await ctx.appambit.db(
    'SELECT id, min_breaks, max_ignored, text FROM report_verdicts ORDER BY rank ASC',
  );

  return {
    week_start: weekStart,
    breaks: week.breaks,
    ignored: week.ignored,
    best_day: week.bestDay,
    longest_streak: week.longest,
    breaks_delta: week.breaks - prior.breaks,
    verdict: pickVerdict(verdicts.results[0].rows ?? [], week),
  };
};
