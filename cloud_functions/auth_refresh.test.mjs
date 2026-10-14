import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';

import { handler } from './auth_refresh.mjs';

const SECRET = 'test-secret';
const b64url = (v) => Buffer.from(v).toString('base64url');

const mint = (sub, exp) => {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify({ sub, iat: Math.floor(Date.now() / 1000), exp }));
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

const decode = (token) => JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8'));
const ctx = (token) => ({ secrets: { AUTH_TOKEN_SECRET: SECRET }, event: { token } });

const now = () => Math.floor(Date.now() / 1000);
const WEEK = 60 * 60 * 24 * 7;

test('a still-valid token is exchanged for a fresh 7-day token', async () => {
  // Old token with only a day left.
  const res = await handler(ctx(mint(7, now() + 60 * 60 * 24)));
  assert.ok(res.token, 'returns a token');
  assert.ok(res.expires_at, 'returns expires_at');

  const claims = decode(res.token);
  assert.equal(claims.sub, 7);
  // New window is ~7 days out (not the old ~1 day).
  assert.ok(claims.exp - now() > WEEK - 60, 'exp is a fresh week');
  // expires_at mirrors the signed exp.
  assert.equal(new Date(res.expires_at).toISOString(), new Date(claims.exp * 1000).toISOString());
});

test('the fresh token verifies under the same secret', async () => {
  const res = await handler(ctx(mint(7, now() + 100)));
  const [h, p, s] = res.token.split('.');
  const expected = createHmac('sha256', SECRET).update(`${h}.${p}`).digest('base64url');
  assert.equal(s, expected);
});

test('an expired token is rejected', async () => {
  const res = await handler(ctx(mint(7, now() - 10)));
  assert.equal(res.error, 'INVALID_TOKEN');
});

test('a tampered token is rejected', async () => {
  const good = mint(7, now() + 100);
  const tampered = `${good.slice(0, -2)}xx`;
  const res = await handler(ctx(tampered));
  assert.equal(res.error, 'INVALID_TOKEN');
});
