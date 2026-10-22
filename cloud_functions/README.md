# Cloud Code functions (AppAmbit)

Canonical source for Unshrimp's backend. These run on **AppAmbit Cloud Code**,
not in the Flutter app. Each is a single self-contained ESM file exporting
`handler` — **Node built-ins only, no npm packages at runtime** (a deploy is one
file with no imports). The `*.test.mjs` files and `_applied_ops.mjs` are helpers
that are never deployed.

> To stand up your own copy, deploy every function below to **your** AppAmbit
> app, create the tables in [`../docs/backend/schema.sql`](../docs/backend/schema.sql),
> and set the `AUTH_TOKEN_SECRET`. The main [README](../README.md#backend-setup-appambit)
> has the full walkthrough.

## The handler contract

A handler takes **one** `ctx` argument (not `(event, ctx)`):

- `ctx.req` — HTTP-trigger envelope `{ method, slug, query, headers, body }`.
- `ctx.event` — the flat payload on a manual run.
- `ctx.appambit.db(sql, params)` — runs SQL against the linked database. Rows
  from `INSERT ... RETURNING` come back positional (arrays), not column-keyed.

Every authenticated function verifies the HS256 session itself (signature **and**
expiry) using `AUTH_TOKEN_SECRET` and `node:crypto`. The device never verifies
the signature — the secret lives only in AppAmbit. A bad/absent token returns
`INVALID_TOKEN`.

## Deployed functions

| Function | In | Out | Notes |
|---|---|---|---|
| `auth_register` | `{ email, password }` | `{ token, expires_at }` | scrypt hash (`scrypt$<salt>$<hash>`, base64); 7-day JWT; seeds `users` + `user_stats`, and starts the 14-day Pro trial once (`entitlement='pro_trial'`, `trial_ends_at`=now+`TRIAL_DAYS` env, default 14) on a partial `user_settings` row. |
| `auth_login` | `{ email, password }` | `{ token, expires_at }` | 7-day HS256 session; `expires_at` is a client convenience, the server still checks the signed `exp`. |
| `auth_refresh` | `{ token }` | `{ token, expires_at }` | Exchanges a still-valid token for a fresh 7-day one. Expired/invalid → rejected. Client swaps the stored pair atomically. |
| `auth_validate` | `{ token }` | `{ valid, user_id? }` | Verifies the HS256 signature + expiry and that the user still exists. **Never cached on the device.** |
| `auth_change_password` | `{ token, old, new }` | `{ ok }` or `{ error }` | Verifies `old` against the scrypt hash, writes the new scrypt hash (`new` ≥ 8 chars). |
| `save_onboarding` | `{ token, answers }` | `{ ...settings, archetype }` | Seeds `user_settings` **server-side** from the 4 answers (`sitting_hours`, `tone`, `pain_zone`, `active_start`, `active_end`) via the deterministic map in PLAN §1.4.1 — never derive interval/goal on the client. Idempotent (`ON CONFLICT(user_id)`). |
| `get_user_stats` | `{ token }` | `{ ...stats }` | The `user_stats` row: streak, `breaks_today`, `ignored_count`, `roast_level`, `roast_pending`. Drives Home. |
| `get_settings` | `{ token }` | `{ ...settings }` or `null` | The `user_settings` row; tone is derived from `roast_threshold`. A pre-onboarding row (trial seeded, no `active_start`) reads as `NO_SETTINGS`, so the user is still sent to onboarding. |
| `get_entitlements` | `{ token }` | `{ is_pro, entitlement, trial_ends_at, pro_until }` | The single source of truth for Pro. Computed from `trial_ends_at`/`pro_until` vs the cloud clock (no cron — the trial expires when read); `pro_until` in the future wins over an expired trial. No settings row → `free`, never an error. |
| `update_settings` | `{ token, ...fields }` | `{ ...settings }` | Edits `user_settings` (incl. `quiet_mode`, `paused_until`); guarantees `active_end > active_start`. |
| `get_stats_history` | `{ token, weeks, tz_offset_min }` | `{ weeks, is_pro, daily_goal, best_streak, goal_met_days, days: [...] }` | Per-day history, oldest→newest, rest days flagged and skipped by the streak. **Pro** gets the requested weeks; **Free** gets only today (the client blurs the weeks). |
| `get_weekly_report` | `{ token, tz_offset_min }` | `{ week_start, breaks, ignored, best_day, longest_streak, breaks_delta, verdict }` or `{ locked: true }` | The weekly Spine Report for the **last complete** Mon–Sun week in the user's local time (missing days = 0), with the breaks delta vs the week before and the verdict text from `report_verdicts` (lowest rank whose conditions the week meets; `{ignored}` filled in; read live so dashboard edits need no release). **Pro** only; **Free** gets `{ locked: true }`. |
| `get_notifications` | `{ token }` | `{ notifications: [...] }` | Newest first, `hidden_at IS NULL`. Times normalized to ISO-8601 UTC. |
| `get_pending_reminders` | `{ token }` | `{ reminders: [...] }` | Rows `WHERE read = 0 AND was_ignored IS NULL` — ignores the user still owes. Ignores `hidden_at`. |
| `register_break` | `{ token, op_id }` | `{ ...stats }` | Counts a completed 60s break. **Idempotent** via `applied_ops` (`op_id` generated when the user taps, not at flush). |
| `reconcile_ignored` | `{ token, ids, tz_offset_min, op_id }` | `{ ...stats, counted }` | Atomic: marks `was_ignored` **and** applies the ignore count in one transaction. **Idempotent**. |
| `mark_all_notifications_read` | `{ token }` | `{ marked }` | |
| `delete_notification` | `{ token, id }` | `{ hidden }` | **Soft** delete (`hidden_at`); never hard-deletes a row that still owes an ignore. |

`_applied_ops.mjs` is the **canonical copy** of the shared idempotency helper
(`applyOnce`). Cloud Code can't import, so it is inlined verbatim into
`register_break` and `reconcile_ignored` (and episode 6's `grant_entitlement`).
Change it here first, then re-inline.

## Secrets

`AUTH_TOKEN_SECRET` is set **per function**, from the AppAmbit **dashboard**,
never in these files and never from a chat. Every authenticated function signs
or verifies the session with it, so it must be the **same value** on all of
them. Env vars (secrets included) are stored on the function and **are
inherited** when you deploy and activate a new version — you do **not** need to
re-set it after a redeploy. But a **brand-new** function starts with an empty
env, so set `AUTH_TOKEN_SECRET` on it **once** before its first authenticated
call. A wrong or whitespace paste fails silently as `INVALID_TOKEN` on every
call.

## Running the helper unit tests

Node 18+, outside `flutter test`:

```bash
node --test 'cloud_functions/**/*.test.mjs'
```
