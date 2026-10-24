import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './log_notifications.mjs';

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

// Mirrors the platform batch: transaction=true wraps the statement results in
// BEGIN/COMMIT entries, so the handler must never count rows out of them.
const makeCtx = (db, input) => ({
  secrets: { AUTH_TOKEN_SECRET: SECRET },
  event: input,
  appambit: {
    batch: async (statements) => {
      db.exec('BEGIN');
      try {
        const results = statements.map(({ sql, params = [] }) => ({
          rows_written: Number(db.prepare(sql).run(...params).changes),
        }));
        db.exec('COMMIT');
        return { results: [{ rows_written: 1 }, ...results, { rows_written: 1 }] };
      } catch (e) {
        db.exec('ROLLBACK');
        throw e;
      }
    },
  },
});

const reminderRows = (db) =>
  db
    .prepare("SELECT title, body, pack, sent_at, read, kind, reminder_key FROM notifications WHERE kind = 'reminder' ORDER BY id")
    .all();

const reminder = (overrides = {}) => ({
  title: 'Unshrimp',
  body: 'Boo.',
  pack: 'default',
  sent_at: '2026-10-24T10:00:00.000Z',
  reminder_key: 'daily-1',
  ...overrides,
});

test('stores one reminder row per delivered reminder, sent_at normalized', async () => {
  const db = seed();
  const out = await handler(makeCtx(db, { token: mintToken(1), notifications: [reminder()] }));
  assert.deepEqual(out, { received: 1 });
  const rows = reminderRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].kind, 'reminder');
  assert.equal(rows[0].reminder_key, 'daily-1');
  assert.equal(rows[0].sent_at, '2026-10-24 10:00:00'); // no T, no Z, no ms
  assert.equal(rows[0].read, 0);
});

test('re-syncing the same delivery does not duplicate', async () => {
  const db = seed();
  const call = () => handler(makeCtx(db, { token: mintToken(1), notifications: [reminder()] }));
  await call();
  await call();
  assert.equal(reminderRows(db).length, 1); // the real effect: still one row
});

test('the same reminder_key on a different day is a new row', async () => {
  const db = seed();
  await handler(makeCtx(db, { token: mintToken(1), notifications: [reminder({ sent_at: '2026-10-24T10:00:00Z' })] }));
  await handler(makeCtx(db, { token: mintToken(1), notifications: [reminder({ sent_at: '2026-10-25T10:00:00Z' })] }));
  assert.equal(reminderRows(db).length, 2);
});

test('a batch stores several at once', async () => {
  const db = seed();
  const out = await handler(
    makeCtx(db, {
      token: mintToken(1),
      notifications: [
        reminder({ body: 'One.', sent_at: '2026-10-24T09:00:00Z', reminder_key: 'daily-1' }),
        reminder({ body: 'Two.', sent_at: '2026-10-24T13:00:00Z', reminder_key: 'daily-2' }),
      ],
    }),
  );
  assert.deepEqual(out, { received: 2 });
  assert.equal(reminderRows(db).length, 2);
});

test('empty list stores nothing', async () => {
  const db = seed();
  assert.deepEqual(await handler(makeCtx(db, { token: mintToken(1), notifications: [] })), { received: 0 });
  assert.equal(reminderRows(db).length, 0);
});

test('a bad token stores nothing', async () => {
  const db = seed();
  const out = await handler(makeCtx(db, { token: 'nope', notifications: [reminder()] }));
  assert.equal(out.error, 'INVALID_TOKEN');
  assert.equal(reminderRows(db).length, 0);
});
