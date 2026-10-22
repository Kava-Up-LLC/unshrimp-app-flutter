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
-- active_days is a 7-char "0/1" mask (Mon..Sun) of the days the user works:
-- reminders fire and ignores count only on active days, and History shows rest
-- days as "rest" without breaking the streak. Default "1111111" (every day).
-- trial_ends_at / entitlement / pro_until drive the 14-day Pro trial and
-- subscriptions (episode 6). auth_register seeds entitlement='pro_trial' and
-- trial_ends_at=now+TRIAL_DAYS once, creating a partial row before onboarding
-- fills the rest; get_entitlements computes is_pro from these timestamps
-- against the cloud clock (the trial expires when read, there is no cron).
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
  pro_until            TEXT,       -- episode 6, reserved
  active_days          TEXT NOT NULL DEFAULT '1111111'  -- "0/1" x7, Mon..Sun
);

-- One row per user per local day, written by register_break / reconcile_ignored
-- and read by get_stats_history and get_weekly_report. day is the user's local
-- "YYYY-MM-DD"; goal_met is 0/1. Missing days are read as zero.
CREATE TABLE IF NOT EXISTS user_daily_stats (
  user_id  INTEGER NOT NULL,
  day      TEXT NOT NULL,                -- user's local "YYYY-MM-DD"
  breaks   INTEGER NOT NULL DEFAULT 0,
  ignored  INTEGER NOT NULL DEFAULT 0,
  goal_met INTEGER NOT NULL DEFAULT 0,   -- 0/1
  PRIMARY KEY (user_id, day)
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

-- The weekly Spine Report verdicts (episode 6). get_weekly_report returns the
-- text of the lowest-rank row whose conditions the week meets; a NULL condition
-- always matches, so the no-condition row is the guaranteed fallback. {ignored}
-- in the text is replaced with the week's ignored count. Editable from the
-- dashboard — the function reads it live, so edits show on the next open with no
-- release. Seed the rows via the MCP (see the episode 6 prompt).
CREATE TABLE IF NOT EXISTS report_verdicts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  rank        INTEGER NOT NULL,   -- lower wins; evaluated ascending
  min_breaks  INTEGER,            -- NULL = no lower bound (always matches)
  max_ignored INTEGER,            -- NULL = no upper bound (always matches)
  text        TEXT NOT NULL
);

-- Episode 6 (subscriptions). One row per store transaction, written by
-- grant_entitlement and restore_entitlement. transaction_id is UNIQUE (orderId
-- when Play sends one, else the purchaseToken), so the same purchase inserts
-- once however many times it is replayed. original_transaction_id is the Play
-- purchaseToken — the stable subscription identity ownership is checked by, so
-- a receipt already bound to another user_id is rejected on restore. The cloud
-- never calls Play, so expires_at is a best-effort bound from the ORIGINAL
-- purchaseTime; restore_entitlement re-extends pro_until on every launch.
CREATE TABLE IF NOT EXISTS purchases (
  id                      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id                 INTEGER NOT NULL,
  store                   TEXT,            -- 'play' | 'app_store'
  product_id              TEXT,
  transaction_id          TEXT NOT NULL,   -- orderId ?? purchaseToken
  original_transaction_id TEXT,            -- Play purchaseToken (ownership key)
  environment             TEXT,            -- 'production' | 'sandbox'
  purchased_at            TEXT,
  expires_at              TEXT,
  raw_payload             TEXT,            -- the signed original JSON
  status                  TEXT,
  created_at              TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_purchases_txn ON purchases (transaction_id);
