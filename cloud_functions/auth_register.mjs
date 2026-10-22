import { createHmac, randomBytes, scryptSync } from 'node:crypto';

// A one-week session (was 30 days). The client also stores expires_at so it can
// decide offline whether to show the app or Log In.
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7;
const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const MIN_PASSWORD_LENGTH = 8;

// Trial length when the TRIAL_DAYS env var is unset or unusable.
const DEFAULT_TRIAL_DAYS = 14;

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

const b64url = (value) => Buffer.from(value).toString('base64url');

/**
 * Signs an HS256 session. Returns both the token and expires_at (ISO 8601 UTC),
 * which mirrors the token's exp claim — expires_at is a client convenience, the
 * server still checks the signed exp on every call.
 */
const signSession = (ctx, userId) => {
  const secret = ctx.secrets?.AUTH_TOKEN_SECRET;
  if (!secret) throw new Error('AUTH_TOKEN_SECRET is not configured');
  const issuedAt = Math.floor(Date.now() / 1000);
  const exp = issuedAt + TOKEN_TTL_SECONDS;
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ sub: userId, iat: issuedAt, exp }));
  const signature = createHmac('sha256', secret)
    .update(`${header}.${payload}`)
    .digest('base64url');
  return {
    token: `${header}.${payload}.${signature}`,
    expiresAt: new Date(exp * 1000).toISOString(),
  };
};

/** scrypt hash as scrypt$<salt>$<hash>, both base64. */
const hashPassword = (password) => {
  const salt = randomBytes(16);
  const derived = scryptSync(password, salt, 64);
  return `scrypt$${salt.toString('base64')}$${derived.toString('base64')}`;
};

const firstColumn = (row, key) => (Array.isArray(row) ? row[0] : row[key]);

export const handler = async (ctx) => {
  const { name, email, password } = readInput(ctx);
  const cleanName = typeof name === 'string' ? name.trim() : '';
  const cleanEmail = typeof email === 'string' ? email.trim().toLowerCase() : '';

  if (
    !cleanName ||
    !EMAIL_PATTERN.test(cleanEmail) ||
    typeof password !== 'string' ||
    password.length < MIN_PASSWORD_LENGTH
  ) {
    return {
      error: 'INVALID_INPUT',
      message: `Enter a name, a valid email and a password of at least ${MIN_PASSWORD_LENGTH} characters.`,
    };
  }

  const existing = await ctx.appambit.db('SELECT id FROM users WHERE email = ?', [cleanEmail]);
  if ((existing.results[0].rows ?? []).length > 0) {
    return { error: 'EMAIL_TAKEN', message: 'That email is already registered.' };
  }

  let userId;
  try {
    const inserted = await ctx.appambit.db(
      'INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?) RETURNING id',
      [cleanName, cleanEmail, hashPassword(password)],
    );
    userId = Number(firstColumn(inserted.results[0].rows[0], 'id'));
  } catch (error) {
    // The UNIQUE index on email is the last word when two signups race.
    ctx.log('register insert failed:', String(error));
    return { error: 'EMAIL_TAKEN', message: 'That email is already registered.' };
  }

  await ctx.appambit.db('INSERT INTO user_stats (user_id) VALUES (?)', [userId]);

  // Start the 14-day Pro trial at account birth. TRIAL_DAYS is a server-side
  // env var (Cloud Code can't read Remote Config); it defaults to 14. The
  // user_settings row is created by save_onboarding, so this seeds a partial
  // row with only the trial fields — save_onboarding's ON CONFLICT upsert fills
  // the rest and leaves these columns untouched. The WHERE guard means the
  // trial is set once and never renewed on a later run.
  const days = Number.parseInt(ctx.env?.TRIAL_DAYS ?? '', 10);
  const trialDays = Number.isInteger(days) && days > 0 ? days : DEFAULT_TRIAL_DAYS;
  const trialEndsAt = new Date(Date.now() + trialDays * 86400000).toISOString();
  await ctx.appambit.db(
    `INSERT INTO user_settings (user_id, entitlement, trial_ends_at)
       VALUES (?, 'pro_trial', ?)
     ON CONFLICT(user_id) DO UPDATE SET
       entitlement = 'pro_trial',
       trial_ends_at = excluded.trial_ends_at
     WHERE user_settings.trial_ends_at IS NULL`,
    [userId, trialEndsAt],
  );

  const session = signSession(ctx, userId);
  return { token: session.token, user_id: userId, expires_at: session.expiresAt };
};
