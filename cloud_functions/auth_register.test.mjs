import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './auth_register.mjs';

const SECRET = 'test-secret';

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL, password_hash TEXT NOT NULL,
      name TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')));
    CREATE UNIQUE INDEX idx_users_email ON users (email);
    CREATE TABLE user_stats (user_id INTEGER PRIMARY KEY, archetype TEXT);
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, active_start TEXT, entitlement TEXT,
      trial_ends_at TEXT, pro_until TEXT);
  `);
  return db;
};

const makeCtx = (db, input, env = {}) => ({
  secrets: { AUTH_TOKEN_SECRET: SECRET },
  env,
  event: input,
  appambit: {
    db: async (sql, params = []) => {
      const stmt = db.prepare(sql);
      if (/^\s*select/i.test(sql) || /\breturning\b/i.test(sql)) {
        return { results: [{ rows: stmt.all(...params) }] };
      }
      const r = stmt.run(...params);
      return { results: [{ rows_written: Number(r.changes) }] };
    },
  },
});

const validInput = { name: 'Grace', email: 'grace@example.com', password: 'password123' };

const settingsOf = (db, userId) =>
  db.prepare('SELECT entitlement, trial_ends_at FROM user_settings WHERE user_id = ?').get(userId);

test('a new user is born on a pro_trial with trial_ends_at = now + TRIAL_DAYS', async () => {
  const db = seed();
  const before = Date.now();
  const res = await handler(makeCtx(db, validInput, { TRIAL_DAYS: '14' }));

  assert.ok(res.user_id, 'returns a user id');
  const row = settingsOf(db, res.user_id);
  assert.equal(row.entitlement, 'pro_trial');
  assert.ok(Math.abs(Date.parse(row.trial_ends_at) - (before + 14 * 86400000)) < 60000);
});

test('TRIAL_DAYS drives the trial length', async () => {
  const db = seed();
  const before = Date.now();
  const res = await handler(makeCtx(db, validInput, { TRIAL_DAYS: '7' }));
  assert.ok(Math.abs(Date.parse(settingsOf(db, res.user_id).trial_ends_at) - (before + 7 * 86400000)) < 60000);
});

test('TRIAL_DAYS defaults to 14 when unset or unusable', async () => {
  const db = seed();
  const before = Date.now();
  const res = await handler(makeCtx(db, validInput, { TRIAL_DAYS: 'nonsense' }));
  assert.ok(Math.abs(Date.parse(settingsOf(db, res.user_id).trial_ends_at) - (before + 14 * 86400000)) < 60000);
});

test('re-registering the same email is rejected and never re-seeds the trial', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, validInput, { TRIAL_DAYS: '14' }));
  // Tamper the stored trial to a sentinel, then try to register the same email.
  db.prepare('UPDATE user_settings SET trial_ends_at = ? WHERE user_id = ?').run(
    '2000-01-01T00:00:00.000Z',
    res.user_id,
  );
  const again = await handler(makeCtx(db, validInput, { TRIAL_DAYS: '14' }));

  assert.equal(again.error, 'EMAIL_TAKEN');
  assert.equal(settingsOf(db, res.user_id).trial_ends_at, '2000-01-01T00:00:00.000Z');
});
