import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler, localDay } from './register_break.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

// UTC, so localDay(now, 0) is the same calendar day date('now') writes.
const TODAY = localDay(Date.now(), 0);

const seed = (dailyGoal = 3) => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
    CREATE TABLE user_stats (
      user_id INTEGER PRIMARY KEY, archetype TEXT, current_streak INTEGER,
      last_break_date TEXT, breaks_today INTEGER, ignored_count INTEGER,
      roast_pending INTEGER, roast_level INTEGER);
    CREATE TABLE user_settings (user_id INTEGER PRIMARY KEY, daily_goal INTEGER);
    CREATE TABLE user_daily_stats (
      user_id INTEGER NOT NULL, day TEXT NOT NULL, breaks INTEGER NOT NULL DEFAULT 0,
      ignored INTEGER NOT NULL DEFAULT 0, goal_met INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, day));
    CREATE TABLE applied_ops (
      op_id TEXT PRIMARY KEY, user_id INTEGER, function TEXT, applied_at TEXT);
    INSERT INTO users VALUES (1, 'Grace');
    INSERT INTO user_stats VALUES (1, NULL, 0, NULL, 0, 0, 0, 0);
    INSERT INTO user_settings VALUES (1, ${dailyGoal});
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

const dailyRows = (db) =>
  db.prepare('SELECT day, breaks, ignored, goal_met FROM user_daily_stats WHERE user_id = 1').all();

test('a break writes one row for today', async () => {
  const db = seed();
  await handler(makeCtx(db, { token: mintToken(1), op_id: 'op-a', tz_offset_min: 0 }));
  const rows = dailyRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].day, TODAY);
  assert.equal(rows[0].breaks, 1);
  assert.equal(rows[0].ignored, 0);
});

test('the same op_id twice leaves one row with breaks 1', async () => {
  const db = seed();
  const ctx = () => makeCtx(db, { token: mintToken(1), op_id: 'op-dup', tz_offset_min: 0 });
  await handler(ctx());
  await handler(ctx());
  const rows = dailyRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].breaks, 1); // the replay rolled back, nothing counted twice
});

test('goal_met flips when breaks reach daily_goal', async () => {
  const db = seed(3); // goal of 3
  const breakOnce = (n) =>
    handler(makeCtx(db, { token: mintToken(1), op_id: `op-${n}`, tz_offset_min: 0 }));
  await breakOnce(1);
  await breakOnce(2);
  assert.equal(dailyRows(db)[0].goal_met, 0); // 2 of 3, not yet
  await breakOnce(3);
  assert.equal(dailyRows(db)[0].goal_met, 1); // 3 of 3, met
});
