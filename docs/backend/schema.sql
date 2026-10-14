-- Unshrimp — AppAmbit Database schema
-- =====================================
-- Run this once against YOUR AppAmbit app's linked database before deploying
-- the Cloud Code functions in ../../cloud_functions/. Nothing in the app or the
-- functions creates these tables at runtime — they are expected to exist.
--
-- How to run it (pick one):
--   • AppAmbit dashboard → your app → Database → SQL console, paste and run.
--   • AppAmbit MCP: execute-database-statement-tool, one statement per entry.
--
-- SQLite dialect (AppAmbit's linked DB is SQLite). Every table is keyed by the
-- integer user id that auth_register returns. Derived from PLAN 1.3 and the SQL
-- in the deployed functions; verify column names against your dashboard if you
-- diverge.

-- Accounts. password_hash is scrypt (scrypt$<salt>$<hash>, both base64) written
-- by auth_register; the session is a signed HS256 JWT, so there is no sessions
-- table (the token carries its own expiry).
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  email         TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  name          TEXT,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- The loop's running numbers. Seeded by auth_register, moved by register_break
-- and reconcile_ignored. roast_level drives the Spine Battery / Camarometro;
-- roast_pending gates the Posture Roast.
CREATE TABLE IF NOT EXISTS user_stats (
  user_id         INTEGER PRIMARY KEY,
  archetype       TEXT,
  current_streak  INTEGER NOT NULL DEFAULT 0,
  last_break_date TEXT,
  breaks_today    INTEGER NOT NULL DEFAULT 0,
  ignored_count   INTEGER NOT NULL DEFAULT 0,
  roast_pending   INTEGER NOT NULL DEFAULT 0,  -- 0/1
  roast_level     INTEGER NOT NULL DEFAULT 0
);

-- Per-user configuration seeded by save_onboarding (deterministic map, PLAN 1.4
-- / 1.4.1) and edited by update_settings. active_start/active_end are wall-clock
-- "HH:mm" with no stored timezone; the app sends tz_offset_min on calls that
-- need the user's local time. quiet_mode and paused_until are per-user.
-- trial_ends_at / entitlement / pro_until are reserved for episode 6 (unused).
CREATE TABLE IF NOT EXISTS user_settings (
  user_id              INTEGER PRIMARY KEY,
  active_start         TEXT,      -- "HH:mm"
  active_end           TEXT,      -- "HH:mm", end > start (no overnight windows)
  reminder_interval_min INTEGER,
  grace_window_min     INTEGER,
  daily_goal           INTEGER,
  roast_threshold      INTEGER,   -- tone is derived from this on read
  pain_zone            TEXT,
  quiet_mode           INTEGER NOT NULL DEFAULT 0,  -- 0/1
  paused_until         TEXT,
  trial_ends_at        TEXT,      -- episode 6, reserved
  entitlement          TEXT,      -- episode 6, reserved
  pro_until            TEXT        -- episode 6, reserved
);

-- One row per reminder shown. was_ignored is written when a reminder expires
-- without a break; hidden_at is a soft delete (the row leaves the Notification
-- Center but get_pending_reminders still sees it, so a still-owed ignore is
-- never silently cancelled).
CREATE TABLE IF NOT EXISTS notifications (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id      INTEGER NOT NULL,
  title        TEXT,
  body         TEXT,
  pack         TEXT,
  sent_at      TEXT NOT NULL,
  read         INTEGER NOT NULL DEFAULT 0,  -- 0/1
  was_ignored  INTEGER,                     -- NULL until reconciled, then 0/1
  reminder_key TEXT,
  hidden_at    TEXT                          -- soft delete; NULL = visible
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, sent_at);

-- Offline write idempotency. Every mutation that can be replayed from the app's
-- outbox (register_break, reconcile_ignored, and episode 6's grant_entitlement)
-- inserts its client-generated op_id here FIRST, inside the same transaction; a
-- replay hits the PRIMARY KEY, the transaction rolls back, and the mutation
-- never applies twice.
CREATE TABLE IF NOT EXISTS applied_ops (
  op_id      TEXT PRIMARY KEY,
  user_id    INTEGER,
  function   TEXT,
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- -- Episode 6 (subscriptions) — not used yet, create it when you add purchases.
-- CREATE TABLE IF NOT EXISTS purchases (
--   id             INTEGER PRIMARY KEY AUTOINCREMENT,
--   user_id        INTEGER NOT NULL,
--   store          TEXT,            -- 'app_store' | 'play'
--   product_id     TEXT,
--   transaction_id TEXT NOT NULL,
--   raw_payload    TEXT,
--   status         TEXT,
--   created_at     TEXT NOT NULL DEFAULT (datetime('now'))
-- );
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_purchases_txn ON purchases (transaction_id);
