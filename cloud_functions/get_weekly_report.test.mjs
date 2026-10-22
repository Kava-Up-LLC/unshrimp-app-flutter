import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler, localDay } from './get_weekly_report.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

// Week math mirrored from the handler so the tests work on any calendar day.
const addDays = (day, n) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + n * 86400000).toISOString().slice(0, 10);
const weekdayIndex = (day) => (new Date(`${day}T00:00:00Z`).getUTCDay() + 6) % 7;
const TODAY = localDay(Date.now(), 0);
const THIS_MONDAY = addDays(TODAY, -weekdayIndex(TODAY));
const WEEK_START = addDays(THIS_MONDAY, -7); // last complete week's Monday
const PRIOR_START = addDays(WEEK_START, -7);

// The four seeded verdict rows, in rank order (null = always matches).
const VERDICTS = [
  [1, 1, 30, 3, 'Seven for seven. Your spine wrote you a thank you note.'],
  [2, 2, 20, null, 'Solid week. Your spine is cautiously optimistic.'],
  [3, 3, null, 5, "Not many breaks, but you didn't ignore me. I'll take it."],
  [4, 4, null, null, 'You ignored me {ignored} times. I counted.'],
];

const seed = ({ pro = true } = {}) => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE user_daily_stats (
      user_id INTEGER NOT NULL, day TEXT NOT NULL, breaks INTEGER NOT NULL DEFAULT 0,
      ignored INTEGER NOT NULL DEFAULT 0, goal_met INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, day));
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, trial_ends_at TEXT, pro_until TEXT);
    CREATE TABLE report_verdicts (
      id INTEGER PRIMARY KEY, rank INTEGER NOT NULL, min_breaks INTEGER,
      max_ignored INTEGER, text TEXT NOT NULL);
  `);
  const proUntil = pro ? new Date(Date.now() + 365 * 86400000).toISOString() : null;
  db.prepare('INSERT INTO user_settings (user_id, trial_ends_at, pro_until) VALUES (1, NULL, ?)').run(proUntil);
  for (const [id, rank, minB, maxI, text] of VERDICTS) {
    db.prepare('INSERT INTO report_verdicts VALUES (?, ?, ?, ?, ?)').run(id, rank, minB, maxI, text);
  }
  return db;
};

const putDay = (db, day, breaks, ignored, goalMet) =>
  db.prepare('INSERT INTO user_daily_stats VALUES (1, ?, ?, ?, ?)').run(day, breaks, ignored, goalMet);

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

const run = (db) => handler(makeCtx(db, { token: mintToken(1), tz_offset_min: 0 }));

test('reports the last complete Monday-to-Sunday week, not the current one', async () => {
  const db = seed();
  // A break on every day of the last complete week + one in the current week.
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 3, 0, 0);
  putDay(db, THIS_MONDAY, 99, 0, 0); // current week — must be ignored

  const res = await run(db);

  assert.equal(res.week_start, WEEK_START);
  assert.equal(res.breaks, 21); // 7 x 3, current week excluded
});

test('missing days count as zero', async () => {
  const db = seed();
  putDay(db, WEEK_START, 4, 0, 1); // only Monday has data
  putDay(db, addDays(WEEK_START, 2), 2, 1, 0); // and Wednesday

  const res = await run(db);

  assert.equal(res.breaks, 6);
  assert.equal(res.ignored, 1);
  assert.equal(res.best_day, WEEK_START); // Monday had the most breaks
});

test('breaks_delta is this week minus the week before', async () => {
  const db = seed();
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 5, 0, 0); // 35
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(PRIOR_START, i), 4, 0, 0); // 28

  const res = await run(db);

  assert.equal(res.breaks, 35);
  assert.equal(res.breaks_delta, 7); // 35 - 28
});

test('longest_streak is the longest run of consecutive goal_met days in the week', async () => {
  const db = seed();
  // Mon,Tue met; Wed miss; Thu,Fri,Sat met; Sun miss  -> longest run = 3.
  const met = [0, 1, 3, 4, 5];
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 4, 0, met.includes(i) ? 1 : 0);

  const res = await run(db);

  assert.equal(res.longest_streak, 3);
});

test('the lowest matching rank wins', async () => {
  const db = seed();
  // 35 breaks, 0 ignored -> meets rank 1 (>=30, <=3) and every lower rank.
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 5, 0, 1);

  const res = await run(db);

  assert.equal(res.verdict, 'Seven for seven. Your spine wrote you a thank you note.');
});

test('rank 2 matches when ignores are too high for rank 1', async () => {
  const db = seed();
  // 35 breaks but 10 ignored -> fails rank 1 (max_ignored 3), meets rank 2 (>=20).
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 5, i === 0 ? 10 : 0, 1);

  const res = await run(db);

  assert.equal(res.verdict, 'Solid week. Your spine is cautiously optimistic.');
});

test('the no-condition row always matches and substitutes {ignored}', async () => {
  const db = seed();
  // 5 breaks, 8 ignored -> fails ranks 1,2 (breaks) and 3 (ignored<=5): rank 4.
  putDay(db, WEEK_START, 5, 8, 0);

  const res = await run(db);

  assert.equal(res.verdict, 'You ignored me 8 times. I counted.');
});

test('a Free user gets only a locked stub', async () => {
  const db = seed({ pro: false });
  for (let i = 0; i < 7; i += 1) putDay(db, addDays(WEEK_START, i), 5, 0, 1);

  const res = await run(db);

  assert.deepEqual(res, { locked: true });
});

test('an invalid token is rejected', async () => {
  const db = seed();
  const res = await handler(makeCtx(db, { token: 'not.a.token', tz_offset_min: 0 }));
  assert.equal(res.error, 'INVALID_TOKEN');
});
