import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler, localDay } from './get_stats_history.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

const TODAY = localDay(Date.now(), 0);

// Pro by default, so the full window is returned; Free users see only today.
const seed = ({ pro = true } = {}) => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE user_daily_stats (
      user_id INTEGER NOT NULL, day TEXT NOT NULL, breaks INTEGER NOT NULL DEFAULT 0,
      ignored INTEGER NOT NULL DEFAULT 0, goal_met INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, day));
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, daily_goal INTEGER, active_days TEXT,
      trial_ends_at TEXT, pro_until TEXT);
  `);
  const proUntil = pro ? new Date(Date.now() + 365 * 86400000).toISOString() : null;
  db.prepare(
    'INSERT INTO user_settings (user_id, daily_goal, active_days, trial_ends_at, pro_until) VALUES (1, 4, ?, NULL, ?)',
  ).run('1111111', proUntil);
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

test('returns zeros for missing days', async () => {
  const db = seed();
  // Only today has data; the other six days of the single week are missing.
  db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, 4, 1, 1)').run(TODAY);

  const res = await handler(makeCtx(db, { token: mintToken(1), weeks: 1, tz_offset_min: 0 }));

  assert.equal(res.daily_goal, 4); // so the screen can show breaks / goal
  assert.equal(res.days.length, 7);
  const today = res.days.find((d) => d.day === TODAY);
  assert.deepEqual(
    { breaks: today.breaks, ignored: today.ignored, goal_met: today.goal_met },
    { breaks: 4, ignored: 1, goal_met: 1 },
  );
  const missing = res.days.filter((d) => d.day !== TODAY);
  assert.equal(missing.length, 6);
  for (const d of missing) {
    assert.deepEqual({ breaks: d.breaks, ignored: d.ignored, goal_met: d.goal_met },
      { breaks: 0, ignored: 0, goal_met: 0 });
  }
});

test('aggregates best streak and goal-met days over the window', async () => {
  const db = seed();
  // Three consecutive goal-met days ending today, plus an isolated met day.
  const dayAt = (back) => localDay(Date.now() - back * 86400000, 0);
  for (const back of [0, 1, 2]) db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, 5, 0, 1)').run(dayAt(back));
  db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, 5, 0, 1)').run(dayAt(5));

  const res = await handler(makeCtx(db, { token: mintToken(1), weeks: 1, tz_offset_min: 0 }));

  assert.equal(res.best_streak, 3); // the run of days 0,1,2
  assert.equal(res.goal_met_days, 4);
});

test('rest days are flagged and skipped by the streak', async () => {
  const db = seed();
  db.prepare("UPDATE user_settings SET active_days = '1111110' WHERE user_id = 1").run(); // Sun off
  const dayAt = (back) => localDay(Date.now() - back * 86400000, 0);
  // Every day of the week met; the one Sunday in the window is a rest day.
  for (let back = 0; back < 7; back += 1) {
    db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, 5, 0, 1)').run(dayAt(back));
  }

  const res = await handler(makeCtx(db, { token: mintToken(1), weeks: 1, tz_offset_min: 0 }));

  const isSunday = (day) => new Date(`${day}T00:00:00Z`).getUTCDay() === 0;
  for (const d of res.days) {
    assert.equal(d.rest, isSunday(d.day) ? 1 : 0, `${d.day} rest flag`);
  }
  // Six work days, all met; the skipped Sunday neither counts nor breaks the run.
  assert.equal(res.goal_met_days, 6);
  assert.equal(res.best_streak, 6);
});

test('an invalid token is rejected', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, { token: 'not.a.token', weeks: 1, tz_offset_min: 0 }));
  assert.equal(res.error, 'INVALID_TOKEN');
});

test('a Free user gets only today, however many weeks are asked for', async () => {
  const db = seed({ pro: false });
  const dayAt = (back) => localDay(Date.now() - back * 86400000, 0);
  for (const back of [0, 1, 2]) db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, 5, 0, 1)').run(dayAt(back));

  const res = await handler(makeCtx(db, { token: mintToken(1), weeks: 3, tz_offset_min: 0 }));

  assert.equal(res.is_pro, false);
  assert.equal(res.days.length, 1);
  assert.equal(res.days[0].day, TODAY);
});

test('a Pro user gets the full requested window', async () => {
  const db = seed(); // pro
  const res = await handler(makeCtx(db, { token: mintToken(1), weeks: 2, tz_offset_min: 0 }));
  assert.equal(res.is_pro, true);
  assert.equal(res.days.length, 14);
});
