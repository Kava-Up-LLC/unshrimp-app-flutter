// cloud_functions/_applied_ops.mjs
//
// SHARED IDEMPOTENCY HELPER — single source of truth, INLINED into each
// function that needs it.
//
// Cloud Code deploys ONE file with no imports, so this is never imported at
// runtime: copy `applyOnce` verbatim into each function (register_break and
// reconcile_ignored inline it today; episode 6's grant_entitlement will too).
// This file is the canonical copy — change it here first, then re-inline.
//
// The applied_ops table is created once out of band (dashboard / MCP), NOT by
// the function:
//   CREATE TABLE applied_ops (op_id TEXT PRIMARY KEY, user_id INTEGER,
//                             function TEXT, applied_at TEXT);
//
// Contract: insert the op_id FIRST, inside the same transaction as the
// mutation. A replayed op_id hits the PRIMARY KEY, the whole BEGIN/COMMIT rolls
// back, and the mutation never applies — so a replayed flush is harmless. A
// replay is told apart from a genuine failure by LOOKING THE ROW UP, never by
// matching the error message.
//
// ⚠️ EPISODE 6 — grant_entitlement: a double-applied purchase is a real
// problem, so grant_entitlement MUST reject a call with no op_id. The
// "apply unguarded when op_id is absent" fallback below is acceptable ONLY for
// the idempotent stat bumps (register_break / reconcile_ignored), where a
// missing id (a legacy client) can safely fall back to the old behaviour.

/**
 * Runs [statements] exactly once per [opId], inside one transaction.
 *
 * Returns { applied: true } when the mutation ran, { applied: false } when this
 * op_id had already been applied (a replay — nothing changed). When [opId] is
 * missing it applies unguarded and returns { applied: true } (legacy clients);
 * callers for whom a replay is dangerous must reject a missing op_id BEFORE
 * calling this.
 */
export const applyOnce = async (ctx, { opId, userId, fn, statements }) => {
  if (typeof opId !== 'string' || opId.length === 0) {
    await ctx.appambit.batch(statements, true);
    return { applied: true };
  }
  try {
    await ctx.appambit.batch(
      [
        {
          sql: `INSERT INTO applied_ops (op_id, user_id, function, applied_at)
                 VALUES (?, ?, ?, datetime('now'))`,
          params: [opId, userId, fn],
        },
        ...statements,
      ],
      true,
    );
    return { applied: true };
  } catch (err) {
    // The transaction rolled back. Is it a replay (op_id already recorded by an
    // earlier successful apply) or a genuine failure? Look for the row.
    const seen = await ctx.appambit.db(
      'SELECT 1 FROM applied_ops WHERE op_id = ?',
      [opId],
    );
    if ((seen.results[0].rows ?? []).length === 0) throw err; // genuine failure
    return { applied: false }; // replay: rolled back, nothing changed
  }
};
