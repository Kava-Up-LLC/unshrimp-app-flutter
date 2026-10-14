import { createHmac, scryptSync, timingSafeEqual } from 'node:crypto';

// A one-week session (was 30 days). The client also stores expires_at so it can
// decide offline whether to show the app or Log In.
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7;

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

const verifyPassword = (password, stored) => {
  const [scheme, salt, hash] = String(stored ?? '').split('$');
  if (scheme !== 'scrypt' || !salt || !hash) return false;
  const expected = Buffer.from(hash, 'base64');
  const actual = scryptSync(password, Buffer.from(salt, 'base64'), expected.length);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
};

const column = (row, index, key) => (Array.isArray(row) ? row[index] : row[key]);

export const handler = async (ctx) => {
  const { email, password } = readInput(ctx);
  // One message for every failure, so it never leaks which emails exist.
  const invalid = { error: 'INVALID_CREDENTIALS', message: 'Invalid email or password.' };

  if (typeof email !== 'string' || typeof password !== 'string') return invalid;

  const found = await ctx.appambit.db(
    'SELECT id, password_hash FROM users WHERE email = ?',
    [email.trim().toLowerCase()],
  );
  const row = (found.results[0].rows ?? [])[0];
  if (!row) return invalid;

  if (!verifyPassword(password, column(row, 1, 'password_hash'))) return invalid;

  const userId = Number(column(row, 0, 'id'));
  const session = signSession(ctx, userId);
  return { token: session.token, user_id: userId, expires_at: session.expiresAt };
};
