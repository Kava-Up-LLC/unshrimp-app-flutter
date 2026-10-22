import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac, createSign, generateKeyPairSync } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

import { handler } from './grant_entitlement.mjs';

const SECRET = 'test-secret';

// A throwaway RSA keypair, standing in for the Play app license key. The public
// half is handed to the function as PLAY_LICENSE_PUBLIC_KEY (base64 SPKI DER),
// exactly as Play Console delivers it.
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

/** Builds the original JSON a Play purchase ships with. */
const receipt = (over = {}) =>
  JSON.stringify({
    packageName: 'com.appambit.unshrimp',
    productId: 'unshrimp_pro_yearly',
    purchaseToken: 'tok-123',
    orderId: 'GPA.1111-2222-3333-44444',
    purchaseTime: Date.now(),
    ...over,
  });

/** RSA-SHA1 signs [payload] with the test private key, base64. */
const sign = (payload) => createSign('RSA-SHA1').update(payload).sign(privateKey, 'base64');

const seed = () => {
  const db = new DatabaseSync(':memory:');
  db.exec(`
    CREATE TABLE user_settings (
      user_id INTEGER PRIMARY KEY, trial_ends_at TEXT, entitlement TEXT, pro_until TEXT);
    CREATE TABLE applied_ops (
      op_id TEXT PRIMARY KEY, user_id INTEGER, function TEXT, applied_at TEXT);
    CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, store TEXT,
      product_id TEXT, transaction_id TEXT NOT NULL UNIQUE, original_transaction_id TEXT,
      environment TEXT, purchased_at TEXT, expires_at TEXT, raw_payload TEXT,
      status TEXT, created_at TEXT DEFAULT (datetime('now')));
    INSERT INTO user_settings (user_id, entitlement) VALUES (1, 'pro_trial');
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

const purchaseRows = (db) => db.prepare('SELECT * FROM purchases WHERE user_id = 1').all();
const settings = (db) =>
  db.prepare('SELECT entitlement, pro_until FROM user_settings WHERE user_id = 1').get();

test('a valid signature grants pro and writes one row', async () => {
  const db = seed();
  const payload = receipt();
  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play', product_id: 'unshrimp_pro_yearly',
      payload, signature: sign(payload), op_id: 'op-grant-1',
    }),
  );

  assert.equal(result.is_pro, true);
  assert.equal(result.entitlement, 'pro');
  assert.equal(settings(db).entitlement, 'pro');
  assert.ok(settings(db).pro_until > new Date().toISOString()); // a year out
  const rows = purchaseRows(db);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].transaction_id, 'GPA.1111-2222-3333-44444');
  assert.equal(rows[0].original_transaction_id, 'tok-123');
});

test('a tampered payload is rejected with INVALID_RECEIPT', async () => {
  const db = seed();
  const payload = receipt();
  const signature = sign(payload);
  // Sign the real payload, then send a different one: the signature no longer matches.
  const tampered = receipt({ productId: 'unshrimp_pro_yearly', purchaseToken: 'tok-evil' });
  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play', payload: tampered, signature, op_id: 'op-grant-2',
    }),
  );

  assert.equal(result.error, 'INVALID_RECEIPT');
  assert.equal(purchaseRows(db).length, 0);
  assert.equal(settings(db).entitlement, 'pro_trial'); // unchanged
});

test('the same transaction twice (different op_ids) leaves one row', async () => {
  const db = seed();
  const payload = receipt();
  const signature = sign(payload);
  const call = (op) =>
    handler(makeCtx(db, { token: mintToken(1), store: 'play', payload, signature, op_id: op }));

  await call('op-a');
  await call('op-b'); // same purchase, fresh op_id (a retry from a new flush)

  assert.equal(purchaseRows(db).length, 1); // transaction_id UNIQUE deduped it
});

test('a replayed op_id rolls back and leaves one row', async () => {
  const db = seed();
  const payload = receipt();
  const signature = sign(payload);
  const call = () =>
    handler(makeCtx(db, { token: mintToken(1), store: 'play', payload, signature, op_id: 'op-dup' }));

  await call();
  await call(); // identical op_id → PK conflict → whole transaction rolls back

  assert.equal(purchaseRows(db).length, 1);
});

test('a missing op_id is rejected (never applied unguarded)', async () => {
  const db = seed();
  const payload = receipt();
  const result = await handler(
    makeCtx(db, { token: mintToken(1), store: 'play', payload, signature: sign(payload) }),
  );

  assert.equal(result.error, 'MISSING_OP_ID');
  assert.equal(purchaseRows(db).length, 0);
});

test('a receipt for another package is rejected', async () => {
  const db = seed();
  const payload = receipt({ packageName: 'com.evil.app' });
  const result = await handler(
    makeCtx(db, {
      token: mintToken(1), store: 'play', payload, signature: sign(payload), op_id: 'op-pkg',
    }),
  );

  assert.equal(result.error, 'WRONG_PACKAGE');
  assert.equal(purchaseRows(db).length, 0);
});
