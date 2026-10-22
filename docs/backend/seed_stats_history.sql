-- Demo seed for the History screen + weekly Spine Report (episode 6, PREP).
-- =============================================================================
-- NOT part of the schema. Fills three full Mon–Sun weeks (plus the current,
-- partial week up to today) of plausible user_daily_stats so History shows week
-- cards and the Spine Report card has a real last-complete week to report. Run
-- ONLY on request, for ONE user_id, via the AppAmbit MCP
-- (execute-database-statement-tool, one statement per entry, transaction = true).
-- Never commit a seeded database; this is demo data.
--
-- WHAT THE SPINE REPORT READS: the LAST COMPLETE week (Mon–Sun, in the user's
-- local time, ending the day before this week's Monday) and the week BEFORE it
-- (for breaks_delta). So the seed must make the last complete week CLEARLY
-- BETTER than the one before — more breaks, fewer ignored — for a strong verdict
-- and a positive "▲ … more breaks than last week".
--
-- CONSISTENCY RULES (so Home and History never disagree on camera):
--   1. Read the user's row FIRST:
--        SELECT current_streak FROM user_stats   WHERE user_id = :user_id;
--        SELECT daily_goal     FROM user_settings WHERE user_id = :user_id;
--   2. The current (partial) week must END in a run of exactly :streak
--      consecutive goal_met days ending TODAY, with the day just before the run
--      NOT met, so Home's current_streak is reproduced exactly. History's
--      best_streak is the longest run in the window and must NEVER come out
--      lower than :streak (a strong last complete week may make it higher — that
--      is fine, best streak and current streak measure different things).
--   3. goal_met days get breaks >= :daily_goal; partial days 1..:daily_goal-1;
--      missed days 0.
--   4. Last complete week: >= 30 breaks total and <= 3 ignored total → the top
--      verdict (rank 1). The week before: clearly fewer breaks and more ignored.
--
-- The concrete day strings and counts are computed at run time from today,
-- :streak and :daily_goal; the block below is the WORKED EXAMPLE it expands to.
--
-- Clear any previous demo rows for this user before re-seeding:
--   DELETE FROM user_daily_stats WHERE user_id = :user_id;

-- ------------------------------------------------------------------------------
-- WORKED EXAMPLE — user_id = 42, current_streak = 3, daily_goal = 4, today =
-- 2026-10-21 (Wed). Four weeks of days, 2026-09-28 .. 2026-10-21:
--   • week -3 (09-28..10-04): moderate activity, so a third week card shows.
--   • week before  (10-05..10-11): WEAK — 13 breaks, 7 ignored, 1 goal-met day.
--   • last complete (10-12..10-18): STRONG — 30 breaks, 1 ignored, 6 goal-met
--     days (10-18 missed, which ends the week and lets the trailing run below be
--     exactly :streak). → verdict rank 1; best day Wed (10-14, 6 breaks);
--     longest streak 6; breaks_delta = 30 - 13 = +17.
--   • current week (10-19..10-21=today): a 3-day goal-met run = current_streak.
-- ------------------------------------------------------------------------------
DELETE FROM user_daily_stats WHERE user_id = 42;

INSERT INTO user_daily_stats (user_id, day, breaks, ignored, goal_met) VALUES
  -- week -3: moderate
  (42, '2026-09-28', 2, 1, 0),
  (42, '2026-09-29', 4, 0, 1),
  (42, '2026-09-30', 1, 1, 0),
  (42, '2026-10-01', 0, 2, 0),
  (42, '2026-10-02', 3, 0, 0),
  (42, '2026-10-03', 2, 0, 0),
  (42, '2026-10-04', 0, 0, 0),
  -- week before the last complete one: WEAK (13 breaks, 7 ignored, 1 met)
  (42, '2026-10-05', 2, 2, 0),
  (42, '2026-10-06', 1, 1, 0),
  (42, '2026-10-07', 3, 0, 0),
  (42, '2026-10-08', 0, 3, 0),
  (42, '2026-10-09', 4, 0, 1),
  (42, '2026-10-10', 2, 1, 0),
  (42, '2026-10-11', 1, 0, 0),
  -- last complete week: STRONG (30 breaks, 1 ignored, 6 met; 10-18 missed)
  (42, '2026-10-12', 5, 0, 1),
  (42, '2026-10-13', 5, 0, 1),
  (42, '2026-10-14', 6, 0, 1),  -- best day of the week
  (42, '2026-10-15', 4, 1, 1),
  (42, '2026-10-16', 5, 0, 1),
  (42, '2026-10-17', 5, 0, 1),
  (42, '2026-10-18', 0, 0, 0),  -- missed, ends the week's run
  -- current (partial) week: trailing run of 3 goal-met days = current_streak
  (42, '2026-10-19', 4, 0, 1),
  (42, '2026-10-20', 4, 0, 1),
  (42, '2026-10-21', 4, 0, 1);  -- today, goal met -> matches current_streak = 3
