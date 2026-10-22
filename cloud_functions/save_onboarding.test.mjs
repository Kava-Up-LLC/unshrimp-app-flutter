import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './save_onboarding.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

// Seeds a user whose settings row already carries the trial auth_register wrote
// (entitlement + trial_ends_at), with the onboarding columns still empty.
const seed = (trialEndsAt) => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE user_stats (
      user_id INTEGER PRIMARY KEY, archetype TEXT, current_streak INTEGER,
      breaks_today INTEGER, ignored_count INTEGER, roast_level INTEGER, roast_pending INTEGER);
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, active_start TEXT, active_end TEXT,
      reminder_interval_min INTEGER, grace_window_min INTEGER, daily_goal INTEGER,
      roast_threshold INTEGER, pain_zone TEXT, quiet_mode INTEGER, paused_until TEXT,
      updated_at TEXT, active_days TEXT NOT NULL DEFAULT '1111111',
      entitlement TEXT, trial_ends_at TEXT, pro_until TEXT);
    INSERT INTO users VALUES (1, 'Grace');
  `);
  db.prepare(
    'INSERT INTO user_settings (user_id, entitlement, trial_ends_at) VALUES (1, ?, ?)',
  ).run('pro_trial', trialEndsAt);
  return db;
};

const makeCtx = (db, input) => ({
  secrets: { AUTH_TOKEN_SECRET: SECRET },
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
    batch: async (statements) => {
      db.exec('BEGIN');
      try {
        const results = statements.map(({ sql, params = [] }) => ({
          rows_written: Number(db.prepare(sql).run(...params).changes),
        }));
        db.exec('COMMIT');
        return { results };
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
    },
  },
});

test('save_onboarding fills the settings and preserves the trial', async () => {
  const trialEndsAt = new Date(Date.now() + 14 * 86400000).toISOString();
  const db = seed(trialEndsAt);

  const res = await handler(
    makeCtx(db, {
      token: mintToken(1),
      answers: {
        sitting_hours: '8-12',
        tone: 'direct',
        pain_zone: 'neck',
        active_start: '09:00',
        active_end: '18:00',
      },
    }),
  );

  assert.equal(res.pain_zone, 'neck'); // onboarding filled the row
  const row = db
    .prepare('SELECT entitlement, trial_ends_at FROM user_settings WHERE user_id = 1')
    .get();
  assert.equal(row.entitlement, 'pro_trial'); // the trial survived the upsert
  assert.equal(row.trial_ends_at, trialEndsAt);
});
