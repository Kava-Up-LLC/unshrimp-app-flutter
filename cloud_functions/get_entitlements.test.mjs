import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler, effectiveEntitlement } from './get_entitlements.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

const iso = (offsetMs) => new Date(Date.now() + offsetMs).toISOString();
const DAY = 86400000;

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, trial_ends_at TEXT, entitlement TEXT, pro_until TEXT);
  `);
  return db;
};

const makeCtx = (db, input) => ({
  secrets: { AUTH_TOKEN_SECRET: SECRET },
  event: input,
  appambit: {
    db: async (sql, params = []) => {
      const stmt = db.prepare(sql);
      if (/^\s*select/i.test(sql)) return { results: [{ rows: stmt.all(...params) }] };
      const r = stmt.run(...params);
      return { results: [{ rows_written: Number(r.changes) }] };
    },
  },
});

const setSettings = (db, { trial = null, entitlement = null, pro = null }) =>
  db
    .prepare('INSERT INTO user_settings (user_id, trial_ends_at, entitlement, pro_until) VALUES (1, ?, ?, ?)')
    .run(trial, entitlement, pro);

test('a live trial reads as pro_trial', async () => {
  const db = seed();
  setSettings(db, { trial: iso(14 * DAY), entitlement: 'pro_trial' });
  const res = await handler(makeCtx(db, { token: mintToken(1) }));
  assert.equal(res.is_pro, true);
  assert.equal(res.entitlement, 'pro_trial');
});

test('a trial_ends_at in the past reads as free', async () => {
  const db = seed();
  setSettings(db, { trial: iso(-1 * DAY), entitlement: 'pro_trial' });
  const res = await handler(makeCtx(db, { token: mintToken(1) }));
  assert.equal(res.is_pro, false);
  assert.equal(res.entitlement, 'free');
});

test('a pro_until in the future reads as pro even when the trial is over', async () => {
  const db = seed();
  setSettings(db, { trial: iso(-30 * DAY), entitlement: 'pro_trial', pro: iso(30 * DAY) });
  const res = await handler(makeCtx(db, { token: mintToken(1) }));
  assert.equal(res.is_pro, true);
  assert.equal(res.entitlement, 'pro');
});

test('no settings row reads as free, not an error', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, { token: mintToken(1) }));
  assert.equal(res.error, undefined);
  assert.equal(res.is_pro, false);
  assert.equal(res.entitlement, 'free');
  assert.equal(res.trial_ends_at, null);
});

test('an invalid token is rejected', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, { token: 'not.a.token' }));
  assert.equal(res.error, 'INVALID_TOKEN');
});

test('effectiveEntitlement: pro_until wins over an expired trial', () => {
  const now = Date.now();
  assert.deepEqual(
    effectiveEntitlement({ trialEndsAt: iso(-1 * DAY), proUntil: iso(DAY) }, now),
    { is_pro: true, entitlement: 'pro' },
  );
  assert.deepEqual(
    effectiveEntitlement({ trialEndsAt: null, proUntil: null }, now),
    { is_pro: false, entitlement: 'free' },
  );
});
