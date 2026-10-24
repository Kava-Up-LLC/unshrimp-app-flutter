import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './record_push.mjs';

const SECRET = 'test-secret';

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL, title TEXT, body TEXT, pack TEXT,
      sent_at TEXT NOT NULL, read INTEGER NOT NULL DEFAULT 0, was_ignored INTEGER,
      reminder_key TEXT, kind TEXT NOT NULL DEFAULT 'reminder', open TEXT, hidden_at TEXT);
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

const pushRows = (db) =>
  db.prepare("SELECT title, body, open, read, kind FROM notifications WHERE kind = 'push'").all();

test('stores one push row', async () => {
  const db = seed();
  const out = await handler(
    makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'report' }),
  );
  assert.deepEqual(out, { stored: true });
  const rows = pushRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].open, 'report');
  assert.equal(rows[0].read, 0);
});

test('the same push twice the same day is one row', async () => {
  const db = seed();
  const ctx = () =>
    makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'report' });
  const first = await handler(ctx());
  const second = await handler(ctx());
  assert.deepEqual(first, { stored: true });
  assert.deepEqual(second, { stored: false }); // deduped
  assert.equal(pushRows(db).length, 1);
});

test('a different open key is a different push', async () => {
  const db = seed();
  await handler(makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'report' }));
  await handler(makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'pro' }));
  assert.equal(pushRows(db).length, 2);
});

test('dedup is per calendar day', async () => {
  const db = seed();
  // A push from yesterday already in the table.
  db.prepare(
    `INSERT INTO notifications (user_id, title, body, sent_at, read, kind, open)
       VALUES (1, 'Spine', 'Ready.', ?, 0, 'push', 'report')`,
  ).run(new Date(Date.now() - 86400000).toISOString());
  await handler(makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'report' }));
  assert.equal(pushRows(db).length, 2); // today's is a new row
});

test('a reminder with the same text does not block the push', async () => {
  const db = seed();
  db.prepare(
    `INSERT INTO notifications (user_id, title, body, sent_at, read, kind)
       VALUES (1, 'Spine', 'Ready.', ?, 0, 'reminder')`,
  ).run(new Date().toISOString());
  const out = await handler(
    makeCtx(db, { token: mintToken(1), title: 'Spine', body: 'Ready.', open: 'report' }),
  );
  assert.deepEqual(out, { stored: true });
  assert.equal(pushRows(db).length, 1);
});

test('a bad token stores nothing', async () => {
  const db = seed();
  const out = await handler(makeCtx(db, { token: 'nope', title: 'x', body: 'y', open: 'report' }));
  assert.equal(out.error, 'INVALID_TOKEN');
  assert.equal(pushRows(db).length, 0);
});
