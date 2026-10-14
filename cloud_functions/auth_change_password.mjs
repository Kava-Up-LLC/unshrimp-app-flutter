import { createHmac, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

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

const MIN_PASSWORD_LENGTH = 8;

/** scrypt hash as scrypt$<salt>$<hash>, both base64 — same format as auth_register. */
const hashPassword = (password) => {
  const salt = randomBytes(16);
  const derived = scryptSync(password, salt, 64);
  return `scrypt$${salt.toString('base64')}$${derived.toString('base64')}`;
};

const verifyPassword = (password, stored) => {
  const [scheme, salt, hash] = String(stored ?? '').split('$');
  if (scheme !== 'scrypt' || !salt || !hash) return false;
  const expected = Buffer.from(hash, 'base64');
  const actual = scryptSync(password, Buffer.from(salt, 'base64'), expected.length);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
};

export const handler = async (ctx) => {
  const { token, old: oldPassword, new: newPassword } = readInput(ctx);
  const payload = readToken(ctx, token);
  if (!payload) return invalidToken;

  if (typeof oldPassword !== 'string' || typeof newPassword !== 'string' ||
      newPassword.length < MIN_PASSWORD_LENGTH) {
    return {
      error: 'INVALID_INPUT',
      message: `Enter your current password and a new one of at least ${MIN_PASSWORD_LENGTH} characters.`,
    };
  }

  const found = await ctx.appambit.db('SELECT id, password_hash FROM users WHERE id = ?', [payload.sub]);
  const row = (found.results[0].rows ?? [])[0];
  // The token outlived its user.
  if (!row) return invalidToken;

  if (!verifyPassword(oldPassword, column(row, 1, 'password_hash'))) {
    return { error: 'WRONG_PASSWORD', message: 'Your current password is incorrect.' };
  }

  await ctx.appambit.db('UPDATE users SET password_hash = ? WHERE id = ?', [
    hashPassword(newPassword),
    Number(column(row, 0, 'id')),
  ]);

  return { ok: true };
};
