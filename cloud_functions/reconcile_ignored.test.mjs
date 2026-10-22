import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import {
  handler,
  isRestToday,
  isWithinWindow,
  localMinuteOfDay,
  toMinutes,
} from './reconcile_ignored.mjs';

// ---- Window helpers (pure) -------------------------------------------------
// A user at UTC-6 with an active window of 09:00..18:00 (their wall clock).
const OFFSET = -360;
const START = '09:00';
const END = '18:00';
const atLocal = (hh, mm) => Date.UTC(2026, 0, 1, hh + 6, mm, 0);

test('UTC-6 just inside the window (09:01 local) counts', () => {
  assert.equal(isWithinWindow(atLocal(9, 1), OFFSET, START, END), true);
});

test('UTC-6 at the exact end (18:00 local) does not count', () => {
  assert.equal(isWithinWindow(atLocal(18, 0), OFFSET, START, END), false);
});

test('malformed bounds never count', () => {
  assert.equal(isWithinWindow(atLocal(12, 0), OFFSET, '9:00', END), false);
});

test('helpers behave', () => {
  assert.equal(toMinutes('09:00'), 540);
  assert.equal(toMinutes('24:00'), null);
  assert.equal(localMinuteOfDay(atLocal(9, 1), OFFSET), 541);
});

test('isRestToday reads the local weekday against the mask (Mon..Sun)', () => {
  const monday = Date.parse('2024-01-01T00:00:00Z'); // a Monday
  const sunday = Date.parse('2024-01-07T00:00:00Z'); // a Sunday
  assert.equal(isRestToday(monday, 0, '0111111'), true); // Mon off
  assert.equal(isRestToday(monday, 0, '1111111'), false); // every day worked
  assert.equal(isRestToday(monday, 0, '1111110'), false); // Sun off, today is Mon
  assert.equal(isRestToday(sunday, 0, '1111110'), true); // Sun off, today is Sun
  assert.equal(isRestToday(monday, 0, 'nope'), false); // malformed -> active
});

// ---- Handler against a real in-memory SQLite -------------------------------
const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

// Force the user's local minute-of-day to noon so the active window below
// always contains "now", whatever time the suite runs.
const noonOffset = 720 - (Math.floor(Date.now() / 60000) % 1440);

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE user_stats (
      user_id INTEGER, archetype TEXT, current_streak INTEGER, breaks_today INTEGER,
      ignored_count INTEGER, roast_level INTEGER, roast_pending INTEGER);
    CREATE TABLE user_settings (
      user_id INTEGER, active_start TEXT, active_end TEXT,
      roast_threshold INTEGER, paused_until TEXT, active_days TEXT);
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY, user_id INTEGER, read INTEGER, was_ignored INTEGER);
    INSERT INTO users VALUES (1, 'Grace');
    INSERT INTO user_stats VALUES (1, NULL, 0, 0, 0, 0, 0);
    INSERT INTO user_settings VALUES (1, '00:00', '23:59', 5, NULL, '1111111');
    INSERT INTO notifications VALUES (1, 1, 0, NULL), (2, 1, 0, NULL);
  `);
  return db;
};

// Mirrors the AppAmbit ctx.appambit surface the handler uses.
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

const pendingCount = (db) =>
  db.prepare('SELECT COUNT(*) AS n FROM notifications WHERE was_ignored IS NULL').get().n;

test('counts the pending rows once and marks them', async () => {
  const db = seed();
  const res = await handler(
    makeCtx(db, { token: mintToken(1), ids: [1, 2], tz_offset_min: noonOffset }),
  );
  assert.equal(res.counted, 2);
  assert.equal(res.ignored_count, 2);
  assert.equal(res.roast_level, 2);
  assert.equal(pendingCount(db), 0);
});

test('a repeated call with the same ids is a no-op', async () => {
  const db = seed();
  const ctx = () => makeCtx(db, { token: mintToken(1), ids: [1, 2], tz_offset_min: noonOffset });

  const first = await handler(ctx());
  const second = await handler(ctx());

  assert.equal(first.counted, 2);
  assert.equal(second.counted, 0); // nothing left pending, so nothing counted
  assert.equal(second.ignored_count, 2); // counter did not move the second time
});

test('outside the active window counts nothing and leaves rows pending', async () => {
  const db = seed();
  // Window 00:00..00:01, with the user forced to noon local -> outside it.
  db.prepare('UPDATE user_settings SET active_start = ?, active_end = ?').run('00:00', '00:01');
  const res = await handler(
    makeCtx(db, { token: mintToken(1), ids: [1, 2], tz_offset_min: noonOffset }),
  );
  assert.equal(res.counted, 0);
  assert.equal(pendingCount(db), 2);
});

test('an invalid token is rejected', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, { token: 'not.a.token', ids: [1], tz_offset_min: 0 }));
  assert.equal(res.error, 'INVALID_TOKEN');
});
