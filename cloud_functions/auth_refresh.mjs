import { createHmac, timingSafeEqual } from 'node:crypto';

// Must match auth_login / auth_register: a one-week session.
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 7;

/**
 * HTTP triggers deliver a request envelope on ctx.req ({ method, slug, query,
 * headers, body }); manual runs deliver the payload flat on ctx.event.
 */
const readInput = (ctx) => ctx.req?.body ?? ctx.req ?? ctx.event ?? {};

const b64url = (value) => Buffer.from(value).toString('base64url');

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

/** Signs a fresh HS256 session (token + expires_at ISO 8601 UTC). */
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

/**
 * Exchanges a still-valid token for a fresh one with a new 7-day window:
 * { token } -> { token, expires_at }. A token that fails the signature or has
 * already expired is rejected (the user must log in again). The caller swaps
 * the stored pair atomically and, on any failure, keeps the old token.
 */
export const handler = async (ctx) => {
  const { token } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  const session = signSession(ctx, payload.sub);
  return { token: session.token, expires_at: session.expiresAt };
};
