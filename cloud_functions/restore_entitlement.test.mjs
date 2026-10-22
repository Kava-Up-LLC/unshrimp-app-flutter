import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, createSign, generateKeyPairSync } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './restore_entitlement.mjs';

const SECRET = 'test-secret';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const PLAY_PUBLIC_KEY = publicKey.export({ type: 'spki', format: 'der' }).toString('base64');

const mintToken = (sub) => {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub, exp: Math.floor(Date.now() / 1000) + 3600 }),
  ).toString('base64url');
  const sig = createHmac('sha256', SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
};

const receipt = (over = {}) =>
  JSON.stringify({
    packageName: 'com.appambit.unshrimp',
    productId: 'unshrimp_pro_monthly',
    purchaseToken: 'tok-123',
    orderId: 'GPA.0001',
    purchaseTime: Date.now(),
    ...over,
  });

const sign = (payload) => createSign('RSA-SHA1').update(payload).sign(privateKey, 'base64');
const signed = (over) => {
  const payload = receipt(over);
  return { payload, signature: sign(payload) };
};

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, trial_ends_at TEXT, entitlement TEXT, pro_until TEXT);
    CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, store TEXT,
      product_id TEXT, transaction_id TEXT NOT NULL UNIQUE, original_transaction_id TEXT,
      environment TEXT, purchased_at TEXT, expires_at TEXT, raw_payload TEXT,
      status TEXT, created_at TEXT DEFAULT (datetime('now')));
    INSERT INTO user_settings (user_id, entitlement) VALUES (1, 'free');
  `);
  return db;
};

const makeCtx = (db, input) => ({
  secrets: { AUTH_TOKEN_SECRET: SECRET, PLAY_LICENSE_PUBLIC_KEY: PLAY_PUBLIC_KEY },
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

const settings = (db) =>
  db.prepare('SELECT entitlement, pro_until FROM user_settings WHERE user_id = 1').get();

test('a 2-month-old subscription reported active keeps the user Pro', async () => {
  const db = seed();
  const twoMonthsAgo = Date.now() - 60 * 86400000; // monthly expiry is long past
  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play',
      purchases: [signed({ purchaseTime: twoMonthsAgo })],
    }),
  );

  assert.equal(result.is_pro, true);
  assert.equal(result.entitlement, 'pro');
  // pro_until floored to ~now + 3 days, so a still-paying user never drops.
  const inTwoDays = new Date(Date.now() + 2 * 86400000).toISOString();
  const inFourDays = new Date(Date.now() + 4 * 86400000).toISOString();
  assert.ok(settings(db).pro_until > inTwoDays && settings(db).pro_until < inFourDays);
});

test('a purchase bound to another user is rejected', async () => {
  const db = seed();
  db.prepare(
    `INSERT INTO purchases (user_id, store, product_id, transaction_id, original_transaction_id, status)
     VALUES (2, 'play', 'unshrimp_pro_monthly', 'GPA.owned', 'tok-owned', 'active')`,
  ).run();

  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play',
      purchases: [signed({ orderId: 'GPA.owned', purchaseToken: 'tok-owned' })],
    }),
  );

  assert.equal(result.error, 'PURCHASE_OWNED_BY_ANOTHER_USER');
  assert.equal(settings(db).entitlement, 'free'); // unchanged
});

test('an empty active list does not downgrade', async () => {
  const db = seed();
  const future = new Date(Date.now() + 30 * 86400000).toISOString();
  db.prepare('UPDATE user_settings SET entitlement = ?, pro_until = ? WHERE user_id = 1').run('pro', future);

  const result = await handler(
    makeCtx(db, { token: mintToken(1), store: 'play', purchases: [] }),
  );

  assert.equal(result.is_pro, true);
  assert.equal(result.entitlement, 'pro');
  assert.equal(settings(db).pro_until, future); // untouched
});

test('a tampered payload is rejected with INVALID_RECEIPT', async () => {
  const db = seed();
  const { payload, signature } = signed();
  const tampered = receipt({ purchaseToken: 'tok-evil' });
  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play',
      purchases: [{ payload: tampered, signature }],
    }),
  );

  assert.equal(result.error, 'INVALID_RECEIPT');
  assert.equal(settings(db).entitlement, 'free');
});
