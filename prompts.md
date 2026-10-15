# The prompts behind Unshrimp

The exact prompts used to build **Unshrimp** on video, in the order they were
sent and grouped by episode. Each prompt is self-contained — it carries its own
copy, values and acceptance checks — so you can read an episode top to bottom
and see how every feature was asked for and built: the account system,
onboarding and settings, local reminders with the 60-second break and the
Notification Center, the Posture Roast with the streak and Spine Battery, and
the offline-first layer.

Prompts marked **PREP** were run off camera before recording; the rest are the
on-camera prompts. For how the app is wired and how to stand up the backend, see
the [README](README.md); for the project's coding rules, see
[CLAUDE.md](CLAUDE.md).

---

# Episode 1 — Account System with Cloud Code (Sign Up, Log In and Session)

## 1. The authentication screens in Flutter

**Goal:** create the `auth` feature with its three screens (Sign Up, Log In and
the session splash) following the project rules, making it clear from the start
that the client never hashes or verifies credentials.

```text
Now the Flutter app, following this project's rules (Riverpod + MVVM +
go_router, NO setState). Create an `auth` feature under lib/features/auth
with the MVVM layout, and three screens:
 - Sign Up: fields name, email, password, confirm password. Validate format
   and that the two passwords match ON THE CLIENT, then call the AppAmbit
   auth_register Cloud Code function. On success store the returned token in
   secure storage and go to Home.
 - Log In: email + password -> call auth_login. Show the backend's
   INVALID_CREDENTIALS message on failure. Add a link to Sign Up.
 - Session gate (splash): on launch read the token from secure storage ->
   call auth_validate -> Home if valid, else Log In.
Wire the routes in go_router. Show loading and error states and disable the
submit button while loading. Do NOT hash or validate credentials on the
client — that all lives in AppAmbit.
```

## 2. The two tables in the AppAmbit database

**Goal:** create `users` and `user_stats` in the AppAmbit database (not a local
SQLite), describing the columns in plain language, and confirm they exist by
listing the tables.

```text
Hey — let's set up the database for MoveWell in AppAmbit (not a local SQLite
inside the app). Use the appambit MCP. I need two tables.

The first one is `users` — one row per person who signs up. Give it an `id`
that's a whole number and auto-increments, and use it as the primary key.
Then a `name` as text that can't be empty; an `email` as text that also can't
be empty and has to be unique, so no two people can share the same email; a
`password_hash` as text that can't be empty; and a `created_at` timestamp
that fills in by itself with the current time.

The second one is `user_stats` — one row per user to keep their progress. It
has a `user_id` (a whole number) that points to the `id` over in the users
table. Then an `archetype` as text that's allowed to be empty; and these
whole-number counters that all start at 0: `current_streak`, `breaks_today`,
`ignored_count`, and `roast_level`. And finally a `roast_pending` true/false
flag that starts as false.

When both are ready, list the tables so we can see them and confirm they're
really there in AppAmbit.
```

## 3. The three Cloud Code functions, wired into the app

**Goal:** create, deploy and activate `auth_register`, `auth_login` and
`auth_validate` without npm, with password hashing always on the server, and
then really connect them to the Flutter screens.

```text
Now create the three Cloud Code functions in AppAmbit for the MoveWell app,
using the appambit MCP. Cloud Code has no npm — use only Node built-ins.

Model: each user has a name, an email, and a password. Store only a hashed
password, never the plaintext. The hashing happens inside the function
(server side), never in the app.

Functions:
- auth_register — takes name, email, password. Reject a weak password or an
  email that already exists (EMAIL_TAKEN). Create the user and their single
  user_stats row. Return a session token and the user id.
- auth_login — takes email and password. On a wrong email or password,
  return the same generic INVALID_CREDENTIALS error. On success, return a
  session token and the user id.
- auth_validate — takes a token and returns whether it's valid and which
  user it belongs to.

Deploy each function, wait until its build is ready, and activate it. Keep
any secret out of the code. Confirm all three are active.

Then actually wire them into the Flutter app — don't just create them, make
the app really use them. Follow this project's rules (Riverpod + MVVM +
go_router, no setState) and put everything under lib/features/auth:
- Sign Up screen: name, email, password, confirm password. Check the format
  and that both passwords match on the phone, then call auth_register. On
  success, save the returned token in secure storage and go to Home.
- Log In screen: email and password → call auth_login. Show the
  INVALID_CREDENTIALS message when it fails, and add a link to Sign Up.
- Session gate (splash): when the app opens, read the saved token and call
  auth_validate — valid → Home, otherwise → Log In.
Wire the routes in go_router, show loading and error states, and disable the
submit button while a request is running. All the real checks live in the
AppAmbit functions, never on the phone.
```

## 4. The round logo on the Log In screen

**Goal:** a small, tightly scoped UI change — the app icon, round and centered,
above the Email field — with an explicit instruction to touch nothing else.

```text
In lib/features/auth/views/log_in_view.dart, show
assets/images/icon_launcher.png at 96x96, centered, above the Email
field, with a SizedBox(height: 32) under it. Clip the image into a
circle (ClipOval, or ClipRRect with BorderRadius.circular(48)) so it
renders round like the current app icon, and use BoxFit.cover so it
fills the circle without distortion.

Also add assets/images/ to the flutter > assets section of pubspec.yaml,
then run flutter pub get.

Change nothing else.
```

## 5. The INVALID_INPUT bug on Sign Up

**Goal:** systematically debug a real failure — `auth_register` rejecting every
HTTP call from the app — demanding evidence before any fix, and checking
whether the other two functions had the same problem.

```text
Sign Up fails in the app. The AppAmbit cloud function auth_register returns
{"error":"INVALID_INPUT","message":"Enter a name, a valid email and a password
of at least 8 characters."} for every call the app makes.

Facts so far, don't assume they point to the cause:
- Every http-triggered invocation returns INVALID_INPUT; every manual
  invocation through the MCP tools with a flat payload succeeds and inserts
  the user.
- The client validates name/email/password before calling, so the banner only
  shows after a server round trip.
- app_key is in .env; use the appambittestingprod MCP tools to inspect the
  function, its logs and the database.

Investigate the whole path before changing anything: the Sign Up view and view
model, AuthRepository._call, how the SDK sends the body, and what the handler
actually receives. Confirm the real cause with evidence (add a temporary
ctx.log if useful) instead of guessing, tell me what you found, then fix it.
Check whether auth_login and auth_validate have the same problem.
```

## 6. The Home screen with real data

**Goal:** build Home (Spine Streak, Camarómetro and today's breaks) with real
values from `user_stats`, which forces a new Cloud Code function that resolves
the user from their session token.

```text
Build the Home screen for MoveWell, a Flutter app that nags you to fix your
posture. The user has just logged in and lands here.

Home shows, for the logged-in user:
- Spine Streak: 🔥 current_streak, the days in a row they met their goal.
- Camarometro ("shrimp meter"): roast_level, 0 to 5, how bad their posture
  habits are right now.
- Today's status: breaks_today.
- A primary button, "Take a break now" (the break screen doesn't exist yet, so
  wire the button and leave the action as a TODO).
- A way to log out: clear the session token from secure storage and go back to
  Log In.

Real values only, no placeholders. They live in the app's AppAmbit database, in
the user_stats table: user_id, archetype, current_streak, breaks_today,
ignored_count, roast_level, roast_pending.

The app reaches that database only through AppAmbit Cloud Code, so Home needs a
function that takes the session token the app keeps in secure storage, resolves
the user and returns their stats. auth_register, auth_login and auth_validate
already exist and sign an HS256 token with the AUTH_TOKEN_SECRET function
secret — read them with the AppAmbit MCP tools and stay consistent with how
they work. Deploy, wait for the build, and activate any function you create.

Project rules: the feature goes in lib/features/home/ following MVVM (models,
views, view_models, widgets). State is Riverpod only — setState is forbidden.
Navigation is go_router with a constant in AppRoutes. Colors come from
Theme.of(context).colorScheme: teal is health, coral is the shrimp/roast side,
amber is the streak.

Tell me your plan before writing code. When you're done, run flutter analyze
and flutter test.
```

---

# Episode 2 — Onboarding that Personalizes + Settings (CMS + per-user Database)

> Home was already built on Episode 1. Episode 2 adds the Onboarding and Settings features and the
> functions `save_onboarding`, `update_settings`, `auth_change_password`. Every prompt below
> carries its own copy and values, so nothing depends on notes off screen. All app copy is
> in English.

## 1. The CMS content (onboarding questions + exercises)

**Goal:** put the onboarding copy and the exercise catalog in the AppAmbit CMS so they can
change without recompiling, with a local fallback.

```text
Using the appambit MCP, set up the CMS content for MoveWell. Create two content types and
seed them with this exact content.

Content type `onboarding_questions` — four questions, in order. Each has a key, a title, a
subtitle, a type and its options (the label the user sees + the value it stores):

1) key: sitting_hours — single choice
   title:    "How many hours a day do you sit?"
   subtitle: "So I know how often to nudge you."
   options:  "Under 4 hours" (0-4) · "4 to 8 hours" (4-8) · "8 to 12 hours" (8-12) · "Over 12 hours" (12+)
2) key: work_schedule — time range (two fields: start and end)
   title:    "What are your work hours?"
   subtitle: "I only bug you inside them."
   defaults: start 09:00, end 18:00
3) key: pain_zone     — single choice
   title:    "Where does it hurt most?"
   subtitle: "I pick your exercises from this."
   options:  "Neck" (neck) · "Shoulders" (shoulders) · "Lower back" (lower_back) · "Wrists" (wrists) · "Nothing yet" (none)
4) key: tone          — single choice
   title:    "How should the app treat you?"
   subtitle: "This sets the Camarometro's tone."
   options:  "Gentle — Cheers you on." (gentle) · "Direct — Reminds you, no fluff." (direct) · "No mercy — Roasts you when you slack." (no_mercy)

Content type `exercises` — short break exercises keyed by pain zone (used later in Episode 3),
based on desk-stretch guidance from Mayo Clinic, Healthline (APTA / physical therapists) and
Cleveland Clinic. Each has a zone, a title and one line of steps. Seed:
- neck:       "Upper trapezius stretch" / "Gently pull your head toward one shoulder, hold 10 to 15 seconds each side." · "Neck rolls" / "Lean your head forward and slowly roll toward each side, hold 10 seconds, 3 times each way."
- shoulders:  "Shoulder rolls" / "Raise both shoulders to your ears, then drop them, repeat 10 times." · "Chest opener" / "Clasp your hands behind your back, push your chest out and lift your chin, hold 10 to 30 seconds."
- lower_back: "Seated knee-to-chest" / "Hug one knee toward your chest, hold 10 to 30 seconds, then switch legs." · "Seated twist" / "Sit tall and rotate your torso holding the chair back, hold 15 seconds each side."
- wrists:     "Wrist flexor stretch" / "Extend your arm palm up, gently pull your fingers down and back, hold 15 to 30 seconds." · "Wrist extensor stretch" / "Extend your arm palm down, gently pull your hand toward you, hold 15 to 30 seconds."
- none:       "Stand and reach" / "Stand up, reach both arms overhead and lengthen your spine, hold 10 to 30 seconds." · "Walk it out" / "Get up and walk for 60 seconds to reset your posture."

In the Flutter app, read both content types through the AppAmbit SDK and keep a local
fallback (a const list with the same content) so the app still works if the CMS is
unreachable. Don't build screens yet — just the content types, the seed data, and the
read + fallback plumbing.
```

## 2. The Onboarding flow + `save_onboarding` (deterministic seeding)

**Goal:** the 4-question onboarding, and a Cloud Code function that turns the answers into a
personalized `user_settings` row ON THE SERVER (never on the phone).

```text
Build the MoveWell onboarding — the "Test of Shame". Follow this project's rules (Riverpod +
MVVM + go_router, no setState); the feature goes in lib/features/onboarding/.

The flow has 4 steps, one question per screen, with a "Step N of 4" progress bar, a bold
title, a muted subtitle, tappable single-choice options (the schedule step uses two time
fields, Start and End), and a primary button ("Continue", and "Finish" on the last). Read
the questions from the CMS `onboarding_questions`; if the CMS can't be reached, fall back to
this exact content:

1) sitting_hours — "How many hours a day do you sit?" / "So I know how often to nudge you."
   → "Under 4 hours" (0-4) · "4 to 8 hours" (4-8) · "8 to 12 hours" (8-12) · "Over 12 hours" (12+)
2) work_schedule — "What are your work hours?" / "I only bug you inside them."
   → Start (09:00) and End (18:00)
3) pain_zone     — "Where does it hurt most?" / "I pick your exercises from this."
   → "Neck" (neck) · "Shoulders" (shoulders) · "Lower back" (lower_back) · "Wrists" (wrists) · "Nothing yet" (none)
4) tone          — "How should the app treat you?" / "This sets the Camarometro's tone."
   → "Gentle" (gentle) · "Direct" (direct) · "No mercy" (no_mercy)

Collect all answers in the view model and DO NOT compute anything from them on the client.
At the end call a NEW AppAmbit Cloud Code function `save_onboarding({ token, answers })`
(appambit MCP, Node built-ins only). It validates the token, resolves the user, and seeds
that user's `user_settings` row entirely on the server:
- reminder_interval_min from sitting_hours:  0-4 → 90 · 4-8 → 60 · 8-12 → 45 · 12+ → 30
- grace_window_min = reminder_interval_min
- active_start / active_end from work_schedule (default 09:00 / 18:00)
- daily_goal = clamp( round( (minutes between active_start and active_end) / reminder_interval_min * 0.5 ), 3, 6 )
- roast_threshold from tone:  gentle → 5 · direct → 3 · no_mercy → 2
- pain_zone from the pain answer
- archetype from sitting_hours:  0-4 → "Shrimp in Training" · 4-8 → "Office Shrimp" · 8-12 → "Hardened Shrimp" · 12+ → "Fossilized Shrimp"
- quiet_mode = false, paused_until = null
Also set user_stats.archetype. Return the seeded row. Deploy the function, wait for the
build to be ready, and activate it. On success navigate to Home.

Tell me your plan before writing code. When done, run flutter analyze and flutter test, and
show me the new user_settings row in the AppAmbit database.
```

## 3. The Settings screen + `update_settings` + `auth_change_password`

**Goal:** edit everything the onboarding seeded, per user, and change the password.

```text
Build the MoveWell Settings screen following this project's rules (Riverpod + MVVM +
go_router, no setState) in lib/features/settings/. It always shows the logged-in user's real
user_settings row (no placeholders), in three groups:

- "Active hours" (active_start / active_end) · "Remind me every" (reminder_interval_min) · "Daily goal" (daily_goal).
- "Quiet mode": a toggle for quiet_mode. When ON, reminders arrive silently — low priority,
  no sound or banner, but still logged and still counted. This is PER USER — a column on that
  user's user_settings row, NOT a global Remote Config flag; changing it must affect only this
  user. "Pause reminders": sets paused_until (sick or on vacation; no reminders while active).
- "Change password"; "Log out" (clear the token from secure storage → Log In).

Two new AppAmbit Cloud Code functions (appambit MCP, Node built-ins, deploy → wait for
ready → activate):
- update_settings({ token, settings }) — validate the token, update only the allowed fields
  of that user's user_settings (active_start, active_end, reminder_interval_min, daily_goal,
  quiet_mode, paused_until), return the updated row.
- auth_change_password({ token, old, new }) — validate the token, verify the old password
  against the stored hash (return WRONG_PASSWORD if it doesn't match), store the new hash.
  Stay consistent with how auth_register hashes.

Show loading and error states, disable buttons while a call runs, and surface the backend
error (e.g. WRONG_PASSWORD). When done, run flutter analyze and flutter test.
```

---

# Episode 3 — Local Reminders + 60s Micro-Break + Notification Center

> State of the app (verified in code): Cloud Code functions that already exist and are called with
> `CloudCode.call('name', body: {...}).future`: auth_register, auth_login, auth_validate,
> save_onboarding, get_settings, update_settings, auth_change_password, get_user_stats. CMS content
> type `exercises` (fields zone, title, steps) is read with `AppAmbitCms.content('exercises')...getList()`.
> The app does NOT yet use Remote Config, Analytics, flutter_local_notifications, or a `notifications`
> table. All app copy is in English. Episode 3 adds the local reminder engine, the 60s break, and the
> Notification Center. Run these in order: #1 is prep (done before recording); #2 to #4 are the on-camera prompts, which the shooting script / script_time.txt label PROMPT 1, 2 and 3.

## 1. Update the exercise data — media + office set  ·  PREP (run before recording)

**Goal:** give every break exercise a picture/gif and replace the CMS catalog with the curated office
set in `assets/dataset/`, keeping all five pain zones covered. Prep for the 60s break screen.

```text
Update the MoveWell exercise data end to end. The 60s break screen (built next) needs a picture per exercise.

Source of truth: the folder assets/dataset/ in this repo (already in place). It has exercises.json (13 office stretches with zone, title, steps and media paths) and media/ (a <id>.gif and a <id>-main.webp for each). The data and images are Unshrimp's own.

1) CMS (use the appambit MCP). The content type is `exercises` with fields zone, title, steps. Add a Media field called `media`. FIRST verify whether the CMS accepts an animated GIF: upload one media/<id>.gif and confirm it stores and returns a `media_url`. If GIF is NOT accepted, use the static media/<id>-main.webp (or a PNG) for every exercise instead, and tell me. Then reseed the `exercises` content from assets/dataset/exercises.json: one entry per exercise with its zone, title, steps, and its uploaded image set on `media`.
   - Keep ALL FIVE pain zones covered. The dataset covers neck, shoulders, lower_back and none, but NOT wrists. So ALSO keep the two existing wrist exercises ("Wrist flexor stretch" and "Wrist extensor stretch") as entries with their steps and no media, so a `wrists` user still gets an exercise.
   - Remove the previous neck/shoulders/lower_back/none entries that the office set replaces, so the catalog ends up as the 13 office exercises + the 2 wrist ones.

2) App model. In lib/features/exercises/models/exercise.dart add a media field (e.g. mediaUrl) and read it in fromCms from `media_url` (the CMS returns a Media field as `<field>_url`). Add an optional local asset path too, so the break screen can fall back to the bundled image when offline.

3) Fallback + assets. Update lib/features/exercises/repositories/fallback_exercises.dart to the SAME catalog you seeded (13 office + 2 wrist), each pointing to its bundled media at assets/dataset/media/<id>.gif (or the -main.webp if GIFs are out). Add assets/dataset/ to the flutter > assets section of pubspec.yaml and run flutter pub get, so the images ship with the app as the offline fallback.

4) Verify. List the `exercises` entries in the CMS and confirm each non-wrist one has a media_url; run flutter analyze and flutter test. Do NOT build the break screen yet.

Tell me your plan before changing anything, and tell me clearly if the CMS rejects GIFs so we decide on static images.
```

## 2. The local reminder engine (no cron)  ·  on-camera prompt 1

**Goal:** schedule recurring reminders as LOCAL notifications driven by the user's `user_settings`,
with the text pulled from AppAmbit Remote Config / CMS. Cloud Code has no cron, so the schedule lives
on the phone.

```text
Build the reminder engine for MoveWell, a Flutter app that nags you to fix your posture. Follow this
project's rules (Riverpod + MVVM + go_router, no setState); the feature goes in
lib/features/reminders/.

IMPORTANT: AppAmbit Cloud Code has NO cron and NO server-side scheduler. The reminders are LOCAL
notifications on the device. Add the flutter_local_notifications package (it is NOT a dependency yet:
run flutter pub add flutter_local_notifications, and do the iOS/Android setup it needs).

Schedule from the logged-in user's settings. Read them with the EXISTING Cloud Code function the app
already uses for this: CloudCode.call('get_settings', body: {'token': token}) returns active_start,
active_end, reminder_interval_min, quiet_mode and paused_until (see lib/features/settings). Do NOT
compute the schedule on the backend.
- Fire one reminder every reminder_interval_min, only inside active_start..active_end.
- If paused_until is set and in the future, schedule NOTHING.
- (reminder intervals are already the set [30, 45, 60, 90], see SettingsOptions.)

When to (re)schedule: on login / app start, and every time Settings are saved. Always cancel the old
local notifications first, then reprogram from the current settings.

The reminder TEXT comes from an AppAmbit Remote Config value `sarcasm_pack` (a list of sarcastic
one-liners). The app does NOT use Remote Config yet: verify the exact Remote Config API in
appambit_sdk_flutter and wire it up; if the SDK needs it, enable config at startup. Create the
`sarcasm_pack` value in AppAmbit with at least a "default" and a "halloween" pack. Cache the pack
locally so an offline phone still shows text; fall back to the CMS, then to a small const list. Pick
a line per reminder.

For development and filming, ALSO add a way to fire a reminder ON DEMAND: a debug-only trigger (a hidden button or a debug menu action) that shows the next reminder within a few seconds, through the SAME code path (schedule + local notification + logging). This is so the whole flow can be tested and filmed without waiting the real 30 to 90 minute interval. It must NOT change the real per-user schedule, and it must be disabled or hidden in release builds.

Ask for notification permission on first run and explain why. Show me, on a phone, the first reminder
landing on the lock screen with the app closed. Tell me your plan before writing code, then run
flutter analyze and flutter test.
```

## 3. The 60s Micro-Break screen (tapping a reminder opens it)  ·  on-camera prompt 2

**Goal:** the break screen the reminder opens, showing the stretch (with its picture) for the user's
pain zone, a 60s timer, and the break_started / break_completed Analytics events.

```text
Build the MoveWell 60s Micro-Break. Follow this project's rules (Riverpod + MVVM + go_router, no
setState); the feature goes in lib/features/break/.

The screen shows ONE short stretch for the user's pain_zone, read from the CMS `exercises` content
type through the existing ExercisesRepository (zone, title, steps, and now a media_url with the
bundled assets/dataset/media fallback from prompt 1). Get the pain_zone from the user's settings
(CloudCode.call('get_settings', ...)). Layout:
- The exercise media (gif or image) in a rounded frame, with the title and the one line of steps.
- A visible 60 second countdown timer (a ring is fine).
- A primary button "Survived", enabled when the timer reaches 0.

Track two Analytics events through the AppAmbit SDK: break_started when the screen opens, and
break_completed ONLY when the timer reaches 0 (or Survived is tapped at 0). If the user leaves before
0, do NOT fire break_completed. NOTE: the app does not use AppAmbit Analytics yet — verify the exact
event-tracking API in appambit_sdk_flutter and wire it up (don't assume the method name).

Wire the tap: when a reminder notification is tapped, open this break screen, even from a cold start
(use the flutter_local_notifications launch/response handler from prompt 2). Pass the pain_zone so it
shows the right stretch. Also wire Home's existing "Take a break now" button to open it.

Show me: tap a reminder -> the break opens -> complete it -> break_completed appears in Analytics; and
leaving early fires nothing. Tell me your plan first, then run flutter analyze and flutter test.
```

## 4. The Notification Center (history of every reminder)  ·  on-camera prompt 3

**Goal:** log every reminder the app shows into an AppAmbit `notifications` table, and build a
Notification Center that lists them read/unread and reopens the break.

```text
Add the Notification Center to MoveWell. Follow this project's rules (Riverpod + MVVM + go_router, no
setState); the feature goes in lib/features/notifications/.

First, using the appambit MCP, create a `notifications` table in the AppAmbit database (it does not
exist yet): an id (whole number, auto-increment, primary key); a user_id (whole number) pointing to
users.id; a title (text); a body (text); a pack (text, e.g. "default" or "halloween"); a sent_at
timestamp that defaults to now; a read true/false that starts false; and a was_ignored true/false
that is allowed to be empty (null for now, used in Episode 4). List the table to confirm it exists.

Every time the app SHOWS a reminder, write one row into `notifications` (title, body, pack, sent_at).
Reach the database only through AppAmbit Cloud Code (Node built-ins only; deploy -> wait for ready ->
activate), resolving the user from the session token, the same way the existing functions do (read
get_user_stats / get_settings with the appambit MCP and stay consistent). The app calls these with
CloudCode.call('name', body: {'token': token, ...}).future. Keep secrets out of the code.

Build the Notification Center screen: list this user's notifications, newest first, with unread ones
visually distinct. Tapping a row opens the 60s break (prompt 3) and marks that row read = true. Add a
way to reach the Center from Home.

Show me: reminders piling up in the Center; tapping one opens the break and marks it read; and after
switching the Remote Config sarcasm_pack to "halloween" in the dashboard, the NEXT reminder lands with
the new text and shows up as a new row, with no rebuild. Tell me your plan first, then run flutter
analyze and flutter test.
```

---

# Episode 3 — Follow-up prompts (in the order they were sent)

## 5. Confirming the reminder engine plan

```text
Go ahead. Confirmations:

Yes, add timezone, flutter_timezone and shared_preferences.
Pause behaviour: keep it as I wrote it (schedule nothing while paused; resumes when the app is next opened). Make sure the reschedule runs on app start.
Yes, cancel reminders on logout.
Keep the debug "Fire test reminder (5 s)" (kDebugMode only).
For verification, use the mobile MCP (mcp-mobile) on my real iPhone: install the build, open the app, fire the debug reminder, lock the phone, and capture the lock-screen screenshot from the device itself. If the mobile MCP can't reach the phone, fall back to the iPhone 17 Pro Max simulator. Run flutter analyze and flutter test first.
```

## 6. Driving the Simulator for the lock-screen capture

```text
Use the mobile MCP (mcp-mobile) to drive the running Simulator instead of AppleScript/cliclick, so no macOS Accessibility is needed. With it: tap "Turn on reminders" › Allow › the gear icon › "Fire test reminder (5 s)", then terminate the app, lock the Simulator, and capture the lock-screen screenshot. If the mobile MCP can't drive the Simulator, tell me and I'll grant Accessibility instead.
```

## 7. Confirming the Micro-Break plan

```text
Go ahead. Answers:
(a) I'll grant macOS Accessibility so you can tap through and verify (I'll also film it myself).
(b) Yes, I'll sign into the AppAmbit dashboard in Chrome so you can show break_completed in Analytics.
Leaving register_break out is correct, that's Episode 4. For Episode 3 the proof is the break_completed event in Analytics. Proceed: flutter analyze + flutter test, wire the tap + the Home "Take a break now" button, and after I sign in, open Analytics (Events) to show break_started and break_completed.
```

## 8. Bug: a scheduled reminder tap shows an error instead of the break

```text
Bug: tapping a SCHEDULED reminder (the ones that fire on their own) shows an error and does NOT open the 60s break. The debug "Fire test reminder" path may behave differently, because a scheduled reminder carries a pain_zone payload while the debug one has none and falls back to get_settings. So the failure is most likely in how the scheduled reminder's payload is parsed and routed into the break.

Do NOT guess or patch blindly. First reproduce and get the real error, then fix.

1) Reproduce with evidence. Trigger a reminder that goes through the SAME code path as the scheduled ones (with the pain_zone payload), tap it, and capture the actual exception and stack trace from the logs, for both cases:
   - warm tap (app already running): the root widget listens to the tap stream and routes to the break;
   - cold start (app closed): the session gate reads the launch payload and opens the break instead of Home.
   Tell me the exact error before changing anything.

2) Inspect the whole tap path end to end:
   - ReminderNotifications: the payload each reminder is scheduled with (format and exact value of pain_zone), onDidReceiveNotificationResponse, the tap stream, and launchPayload()/getNotificationAppLaunchDetails();
   - how MoveWellApp (warm) and the session gate (cold) turn that payload into the route /break?zone=…&source=reminder;
   - BreakArgs parsing of the zone/source query params;
   - break_view_model loading: the zone from args, the exercise_picker, ExercisesRepository, and the get_settings fallback;
   - null/empty handling: an unknown or empty zone, an exercise with no media_url, or a failed CMS/get_settings call.

3) Fix the real cause you proved (not a symptom). Make a tapped scheduled reminder open the break with the correct exercise for its zone, on both warm tap and cold start. Keep the debug trigger working too.

4) Add/adjust a test that covers this exact case (a scheduled reminder's payload → the break opens with that zone), so it can't regress. Then run flutter analyze and flutter test, and show me it opens without the error.
```

## 9. Notification Center: secret set, verify and run the demo

```text
Done. I added AUTH_TOKEN_SECRET (same value as get_settings, marked secret) to log_notifications, get_notifications and mark_notification_read. Verify the three functions with a real token, then run the demo on the simulator: fire a few debug reminders so rows pile up and show them in the Center; tap a row so the break opens and the row turns read; then switch sarcasm_pack active to halloween, reopen the app, and show the next reminder arriving as a new halloween-tagged row.
```

## 10. Remote Config: stale value or failed fetch

```text
Do option 1 first: attach with flutter attach and capture exactly what the SDK receives for sarcasm_pack at launch (the RemoteConfig "Received response" log), and whether that launch fetch succeeds or the app falls back to a stored value. Tell me which it is:
(a) the backend returns a stale value (cache/propagation lag), or
(b) the fetch fails (or a stale stored value is preferred over a successful fetch).

If (a): that's the known "Remote Config updates on next launch" behavior. Wait until the app reads default again, then do a clean run: set the server to halloween, confirm with list-app-configs, relaunch until the app actually reads halloween, fire the next reminder, and show the new halloween row.

If (b): fix it so a successful launch fetch always wins and the app reflects the SERVER value on relaunch (make sure enableConfig() runs before start(), and don't silently serve a stale stored value over a good fetch). Then redo step 3 cleanly.

Do not show a halloween row until the app's value matches the server.
```

## 11. Unread badge on the Home bell

```text
Add an unread badge to the notifications bell on the MoveWell Home screen. Follow this project's rules (Riverpod + MVVM + go_router, no setState).

Goal: a small red dot on the top-right corner of the bell icon that shows ONLY when the user has unread notifications (read = false), and is hidden when there are none. Just a dot, no number.

Reuse what already exists from the Notification Center:
- Read unread state from the existing notifications repository (the one that calls get_notifications). Derive "has unread" from the rows (any with read == false). Do NOT add a new Cloud Code function or a new function secret for this unless you can show it's clearly needed; reusing get_notifications is fine.
- Put the unread state in a Riverpod provider (e.g. hasUnreadNotificationsProvider) that both Home (the badge) and the Center can rely on.

Keep it in sync (this is the important part):
- Refresh it when Home appears, when the app returns to the foreground, and after the Center changes. Tapping a row in the Center to mark it read must make the dot update (invalidate/refresh the shared provider so Home reflects it without a manual reload).
- Marking read in the Center already updates the row; make sure the Home dot follows.

Style: use the app's coral/red accent (Theme.of(context).colorScheme), a small dot with a subtle border so it reads on the icon. Don't shift the bell's layout.

Tests: the dot shows when there is at least one unread, is hidden when there are none, and disappears after the last unread is marked read. Then run flutter analyze and flutter test. Tell me your plan before writing code.
```

```text
Yes
```

## 12. Bug: a reminder opened from the OS tray is not marked read

```text
Bug: opening a reminder from the phone's OS notification tray (or lock screen) opens the break but does NOT mark that notification as read. Its row in `notifications` stays read = false, so the Home unread badge stays on. Tapping the row inside the in-app Notification Center DOES mark it read correctly; the gap is only the OS-notification tap path (warm tap and cold start).

Do not guess. First reproduce and confirm the cause with evidence, then fix.

1) Reproduce: send a reminder through the same path as a scheduled one, tap it from outside the app (warm tap with the app backgrounded, and a cold start), let the break open, and confirm in the database that the matching `notifications` row is still read = 0 and the badge (hasUnreadNotificationsProvider) is still true.

2) Fix: when a reminder tap opens the break, mark THAT notification's row as read via the existing mark_notification_read, on both warm tap and cold start. Handle the two real complications:
   - Mapping: the tapped OS notification must map to its `notifications` row. If there is no reliable key today, add a stable id to the reminder payload and store it on the logged row so the tap can find the exact row. Do not mark unrelated rows.
   - Timing: the row may only be logged during a sync (app start / foreground / Center open). So on a reminder tap, run the log/sync first, then mark the matching row read. If the row can't be found even after syncing, fail quietly (don't crash, don't mark the wrong row).
   Then refresh the badge so it clears if that was the last unread.

3) Keep the in-app Center tap behavior exactly as it is (it already works).

4) Add a test: a reminder tapped from OUTSIDE the Center marks its own notification read and clears the badge when it was the last unread; and it does not mark other rows read. Then run flutter analyze and flutter test. Tell me your plan before writing code.
```

```text
Go ahead, the plan is right. The reminder_key is the correct way to identify which notification was tapped, and the backward-compat (nullable column, old plain-zone payload fallback, replaced on next reschedule) is good. Two checks:
- After you redeploy log_notifications and get_notifications to v2, VERIFY they still have AUTH_TOKEN_SECRET set (it should persist across versions, but confirm so they don't start failing).
- Keep the quiet failure (no match -> do nothing, never mark another row).
Then run flutter analyze and flutter test, and redo the warm-tap repro on the simulator to show the row turning read and the badge clearing.
```


# Episode 4 — Ignored Reminders + Posture Roast + Streak & Spine Battery

> ⚠️ **Cloud Code lifecycle (learned the hard way — applies to prompts 3 and 4 below).**
> For EVERY Cloud Code function created in this project the full lifecycle is:
> create → deploy → wait for build `ready` → activate → **add the HTTP trigger**
> (`set-cloud-function-trigger`, type `http`, slug = function name, enabled) → **remind the
> user to set `AUTH_TOKEN_SECRET`** on the active version (same value as the auth functions;
> it can't be read back, so a wrong/whitespace paste fails silently as INVALID_TOKEN) →
> **verify with a real token via MCP** (`auth_register`/`auth_login`, then call the function —
> it must NOT return INVALID_TOKEN). Missing trigger → the app's `CloudCode.call` fails with
> "Something went wrong"; mismatched secret → every token is INVALID_TOKEN. Note:
> `default_timeout_ms` (default 10000, too low for cold starts) can only be set at create
> time or in the dashboard — there is no MCP tool to change it afterward.

> State of the app (verified in code on `feature/roast-streak-engine`): Cloud Code functions already
> called with `CloudCode.call('name', body: {'token': token, ...}).future`: auth_register, auth_login,
> auth_validate, auth_change_password, save_onboarding, get_settings, update_settings, get_user_stats,
> log_notifications, get_notifications, mark_notification_read. `user_stats` already has
> ignored_count, roast_level, roast_pending, breaks_today, current_streak, last_break_date (all 0 /
> false today; nothing writes them). `user_settings` has roast_threshold, daily_goal,
> grace_window_min. `notifications` has was_ignored (null, reserved) and reminder_key. The Home reads
> get_user_stats into UserStats (lib/features/home/models/user_stats.dart) and paints
> CamarometroCard (roast_level 0..5), SpineStreakCard and BreaksTodayCard. The break
> (lib/features/break/) starts its 60 s countdown as soon as it opens and tracks break_started on
> open. The app name is "MoveWell" in: lib/core/config/move_well_app.dart (MaterialApp title),
> lib/features/home/views/home_view.dart (AppBar), lib/features/reminders/repositories/
> reminder_notifications.dart (notification title), lib/features/reminders/views/
> reminder_permission_view.dart ("Let MoveWell nag you"), ios/Runner/Info.plist
> (CFBundleDisplayName / CFBundleName), android/app/src/main/AndroidManifest.xml (android:label),
> DESIGN.md and CLAUDE.md. Decisions from the plan: the app is now **Unshrimp**, the meter is now
> **Spine Battery**, the break waits for a Start tap. Run in order: #1 is prep (before recording); #2
> is a short on-camera beat; #3 to #5 are the on-camera prompts the shooting script labels PROMPT 1,
> 2 and 3. Always say "episode", never "day", in anything that ends up on screen.

## 1. The break waits for you: Start + 3, 2, 1  ·  PREP (run before recording)

**Goal:** the 60 s countdown must not start by itself when the break opens. Reviewer feedback from
episode 3. Small change, done off camera so the break shown in episode 4 already behaves this way.

```text
Change the 60s micro-break in lib/features/break/ so the countdown does NOT start when the screen opens.

Today BreakViewModel starts ticking and tracks break_started in build(). Change it to:
1) The screen opens showing the exercise (image, title, steps) with the timer at 60 and a primary button "Start". Nothing ticks yet and NO analytics event is sent on open.
2) Tapping Start tracks break_started (same payload as today, with the zone), shows a 3, 2, 1 countdown (one second each, big centered digits over the exercise), then runs the 60s countdown exactly as today.
3) Keep everything else the same: break_completed only when it reaches 0, "Survived" enabled only then, leaving earlier tracks nothing, a reminder tap still opens the break and marks its notifications row read via reminder_key. No pause button during the 60s.

Model this as a phase in BreakState (ready / countingIn / running / done) instead of booleans, keep Riverpod + MVVM + go_router and no setState, and update the tests in test/features/break/ so they cover: nothing tracked on open, break_started on Start, the 3-2-1 before the 60s. Run flutter analyze and flutter test. Do not touch the reminder engine or the Notification Center. Tell me your plan before changing anything, and wait for my OK.
```

## 2. Rename the app to Unshrimp and the meter to Spine Battery  ·  on-camera quick beat (speed-ramp)

**Goal:** apply the two naming decisions as one visible change at the top of the episode. Show the
prompt and the result (Home with the new name and the new card), nothing else.

```text
Two renames from the episode 3 feedback, UI and copy only. Do NOT change the Dart package name (move_well_app), the Android applicationId / namespace, the iOS bundle identifier, the AppAmbit app or key, or any database field; those stay for now.

1) The app is now called "Unshrimp". For the native app name use the Flutter `rename` CLI package, not hand edits: run `flutter pub global activate rename` (skip if already active), then `rename getAppName --targets ios,android` to show the current name, then `rename setAppName --targets ios,android --value "Unshrimp"`. That updates CFBundleDisplayName / CFBundleName in ios/Runner/Info.plist and android:label in android/app/src/main/AndroidManifest.xml; show me the diff of those two files. Do NOT run setBundleId or change applicationId / namespace. Then replace the remaining user-visible "MoveWell" strings in Dart by hand: the MaterialApp title in lib/core/config/move_well_app.dart, the Home AppBar title in lib/features/home/views/home_view.dart, the notification title in lib/features/reminders/repositories/reminder_notifications.dart, and the headline "Let MoveWell nag you" in lib/features/reminders/views/reminder_permission_view.dart; plus the pubspec.yaml description and the references in DESIGN.md and CLAUDE.md. Keep the current icon. Grep the repo for "MoveWell" afterwards and show me what is left (code comments and the class name MoveWellApp may stay).

2) The Home meter "Camarómetro" is now "Spine Battery": a battery that drains with every ignored reminder and recharges with every completed break. It still reads user_stats.roast_level (0 to 5), but it is displayed as charge: 5 segments filled = 5 - roast_level, and a percent = (5 - roast_level) * 20. Rename CamarometroCard to SpineBatteryCard (file spine_battery_card.dart), keep the coral color, and use these labels by charge: 100% "Fully charged", 80% "Running fine", 60% "Getting low", 40% "Low battery", 20% "Critical", 0% "Dead. Stretch to recharge." Update the doc comments, DESIGN.md and CLAUDE.md, and every other "Camarómetro"/"Camarometro" string in lib/ and test/. The onboarding tone question's subtitle "This sets the Camarometro's tone." becomes "This sets how fast your Spine Battery drains." in the fallback (lib/features/onboarding/repositories/fallback_onboarding_questions.dart) AND in the CMS entry of the onboarding questions (use the appambit MCP to update that content), so the app and the cloud say the same thing.

Run flutter analyze and flutter test, then run the app so I can see Home with "Unshrimp" in the AppBar and the Spine Battery card at 100%. Tell me your plan before changing anything, and wait for my OK.
```

## 3. The brain in the cloud: register_break and register_ignore  ·  on-camera prompt 1

**Goal:** the two Cloud Code functions that decide "did / did not", atomic, returning the new
`user_stats`. Nothing is counted on the phone. The expected failure to capture: the agent counting
on the client or writing without a transaction (double tap duplicates the streak).

```text
The Home already shows Spine Battery, Spine Streak and Breaks today from get_user_stats, but they never move because nothing decides "did the break / ignored the reminder". Build that decision in AppAmbit Cloud Code, server-side and atomic. Do NOT count anything on the phone: the app only reports what happened and refetches the stats the function returns.

Create two Cloud Code functions (Node built-ins only; resolve the user from the session token exactly like get_user_stats does; read get_user_stats and update_settings with the appambit MCP first and stay consistent; deploy -> wait for ready -> activate; keep secrets out of the code):

- register_break({token}): in ONE batchInTransaction on user_stats: ignored_count = 0; roast_level = max(0, roast_level - 1); breaks_today = breaks_today + 1 (reset to 1 if last_break_date is before today); if breaks_today >= user_settings.daily_goal and last_break_date != today then current_streak = current_streak + 1; last_break_date = today; roast_pending = false. Return the full updated user_stats row.
- register_ignore({token, count}): count is a whole number >= 1. In ONE batchInTransaction: ignored_count = ignored_count + count; roast_level = min(5, roast_level + count); if ignored_count >= user_settings.roast_threshold then roast_pending = true. Only count when the user is inside their active window (active_start..active_end) and paused_until is null or in the past; otherwise return the row unchanged with ignored: 0. Return the full updated row.

Both must be safe against a double call: calling register_break twice in the same second must not increment current_streak twice (the last_break_date != today check must be inside the transaction).

In the app: when the 60s break reaches 0 and the user taps Survived, call register_break and replace the Home stats with the returned row (no local math). Add a temporary debug action in Settings next to "Fire test reminder (5 s)": "Register ignore (debug)" that calls register_ignore with count 1, so I can see the row change in the dashboard. Keep it behind kDebugMode like the other debug tools.

Do not build the Posture Roast screen or the reconciliation yet. Run flutter analyze and flutter test, show me both functions active, then run the app so I tap "Register ignore (debug)" and we watch user_stats in the AppAmbit dashboard: ignored_count 1, roast_level 1, and Spine Battery drops to 80%. Tell me your plan before changing anything, and wait for my OK.
```

## 4. The app finds out: reconciliation of expired reminders  ·  on-camera prompt 2

**Goal:** on launch and on resume, the app checks which reminders expired without a completed
break and reports them ONCE. Marks `notifications.was_ignored = true` through Cloud Code.
Lessons from prompt 3 baked in: HTTP trigger + secret via MCP + real-token check for every new
function; `tz_offset_min` on every `register_ignore` call; the active-window rule is a feature, not a
bug, so the UI says why nothing was counted.

```text
Now make the app notice the reminders I ignored. Add a reconciliation step that runs when the app launches and when it comes back to the foreground.

1) Cloud Code. Add get_pending_reminders({token}) that returns this user's notifications rows with read = false and was_ignored IS NULL (id, reminder_key, sent_at), and mark_ignored({token, ids}) that sets was_ignored = true on those rows for this user only (notifications.id is the primary key). Node built-ins only, same readToken helper as register_ignore. For EACH function follow the full lifecycle: create -> deploy -> wait until ready -> activate -> add the HTTP trigger (slug = function name, enabled) -> set AUTH_TOKEN_SECRET with set-cloud-function-env marked secret, same value register_ignore has (ask me for it if you don't have it; never write it to a file, log, test or commit) -> verify with a fresh throwaway user and a real token via the MCP, then delete that user. Show me the final state (active, trigger, env set, verified).

2) App. In lib/features/reconcile/ (Riverpod + MVVM, no setState): on launch and on resume, fetch the pending rows. A reminder is "expired" when now > sent_at + grace_window_min (from get_settings) and it was sent inside the user's active window, both computed in the DEVICE's local time. If there are N expired rows: call register_ignore with count N and tz_offset_min (DateTime.now().timeZoneOffset.inMinutes, like the debug action already does), then mark_ignored with their ids, then apply the returned user_stats to Home (applyStats) so the Spine Battery updates. If N is 0 do nothing. Never call register_ignore for rows already marked, so reopening the app does not count twice. If register_ignore returns ignored: 0 (outside active hours or paused), still mark nothing and surface the reason in debug output; that is the business rule, not an error.

3) Settings debug. Add "Reconcile now (debug)" behind kDebugMode, next to "Register ignore (debug)": it runs the same reconciliation but treats every pending row as expired, so I can demo it without waiting for the grace window. Both debug actions' SnackBars must show the Spine Battery percent ("ignored 3, battery 40%"), not "roast x/5". When register_ignore comes back with ignored: 0, the SnackBar says "Not counted: outside active hours or reminders paused".

Tests: the expired-row rule (inside/outside window, before/after grace), the "never twice" rule, and that tz_offset_min is sent. Run flutter analyze and flutter test.

Demo setup, before you run the app: my test user must have roast_threshold = 3 (tone "direct"); check get_settings and tell me if it is not, so I change the tone in Settings first. The active window is already widened for recording. I have 3 untouched reminders in the Center. Then I tap "Reconcile now (debug)" and we watch user_stats go to ignored_count 3, roast_level 3, roast_pending true, Spine Battery 40%, and the three notifications rows flip to was_ignored = true. Then I reopen the app to prove it does not count again. Tell me your plan before changing anything, and wait for my OK.
```

## 5. The Posture Roast and the way back  ·  on-camera prompt 3

**Goal:** full-screen punishment when `roast_pending` is true, with the roast text living in Remote
Config, and the break from there clearing everything. No new Cloud Code function; `register_break`
already runs on "Survived" since prompt 3.

```text
Build the Posture Roast. When get_user_stats returns roast_pending = true, the app shows a full-screen roast BEFORE Home, on launch and right after a reconciliation that sets it, in lib/features/roast/ (Riverpod + MVVM + go_router, no setState):

- Coral background (colorScheme.secondary), the shrimp art from assets/images, one big roast line, the Spine Battery card at its current charge (percent, same widget as Home), and two buttons: "Fix my posture" (primary) and "Share my shame" (secondary, OS share sheet with the roast line followed by " — Unshrimp").
- Roast lines come from AppAmbit Remote Config key roast_lines, a JSON array of strings. Create the key with the appambit MCP if it has a Remote Config tool; if not, give me the exact key name and JSON to paste in the dashboard and wait. Seed these three lines: "Three reminders ignored. Your chair has officially adopted you." / "You had one job: stand up. The shrimp won." / "Museum skeletons are laughing at you right now." Pick one at random per roast. Cache the last fetched array the same way sarcasm_pack is cached so the roast still shows offline; fall back to the first line if nothing is cached.
- "Fix my posture" opens the existing 60s break for the user's pain_zone with source = roast (Start, 3-2-1, 60s, Survived). Survived already calls register_break and applies the returned stats; since that function sets roast_pending = false and ignored_count = 0, just go to Home afterwards. Leaving the break early keeps roast_pending true, so the roast shows again on next launch. No pause button, no way to dismiss the roast without the break (back gesture returns to the roast).
- Routing: a redirect in app_router.dart sends to the roast whenever the current user_stats has roast_pending = true, and back to Home when it is false. Make sure the redirect reads the stats the reconciliation just applied, not a stale copy.
- Track roast_shown and roast_shared in Analytics.

Tests: redirect on/off by roast_pending, random line from the cached array, fallback line when cache is empty. Run flutter analyze and flutter test.

Demo: my user has roast_pending true from prompt 2 and Spine Battery 40%. I relaunch the app, we see the roast, I tap "Share my shame" to show the sheet and cancel, then "Fix my posture", Start, 3-2-1, survive, and we watch user_stats go to ignored_count 0, roast_pending false, roast_level 2, breaks_today +1, with Home back at 60%. Then I change one roast line in Remote Config and force another roast to show the new text with no rebuild. Tell me your plan before changing anything, and wait for my OK.
```
---

# Episode 5 — Offline First: the app that does not need a signal

> ⚠️ **Cloud Code lifecycle (same as episode 4 — applies to prompts 3 and 4 below).**
> For EVERY new Cloud Code function: create → deploy → wait for build `ready` → activate →
> **add the HTTP trigger** (`set-cloud-function-trigger`, type `http`, slug = function name,
> enabled) → **remind me to set `AUTH_TOKEN_SECRET`** on the active version (same value as the
> auth functions; it cannot be read back, so a wrong or whitespace paste fails silently as
> INVALID_TOKEN) → **verify with a real token via MCP** (`auth_login`, then call the function —
> it must NOT return INVALID_TOKEN). Missing trigger → the app's `CloudCode.call` fails with
> "Something went wrong"; mismatched secret → every token is INVALID_TOKEN. `default_timeout_ms`
> can only be set at create time or in the dashboard.

> ⚠️ **No staged failures, from this episode on.** Nothing is broken on purpose and no bug is
> provoked to be fixed on camera. Crash Reporting gets wired correctly and is mentioned, but
> nothing is crashed. Do not add a "test crash" button and do not suggest one, and do not propose
> "let's show what happens when it fails" as a demo beat. The episode shows features working.
> Hardening still happens in code; it just is not dramatized.

> **State of the app (verified in code on `feature/ignored-reminders-roast-streak`).**
> 15 Cloud Code functions are called today: auth_register, auth_login, auth_validate,
> auth_change_password, save_onboarding, get_settings, update_settings, get_user_stats,
> register_break, register_ignore, get_pending_reminders, mark_ignored, log_notifications,
> get_notifications, mark_notification_read. Six of them have local sources in
> `cloud_functions/`; the other nine exist only in the AppAmbit dashboard. Every repository goes
> through `lib/core/cloud/cloud_functions.dart`, which retries exactly once on a transient
> `http`/`timedOut` error but ONLY for idempotent reads, never for mutations.
> **There is no read cache and no write queue anywhere in the project.** `shared_preferences` is
> already a dependency and is used in exactly two places (`delivery_log.dart`,
> `reminder_preferences.dart`); there is no sqflite/hive/drift and no connectivity plugin. The
> hardcoded `fallback_*` files are generic seed content, not "the last thing the user saw".
> `AppBootstrap.run()` starts the SDK and nothing installs `FlutterError.onError`,
> `PlatformDispatcher.instance.onError` or a `runZonedGuarded`, so framework and async errors
> are not routed anywhere today. The reminder scheduler uses
> `AndroidScheduleMode.inexactAllowWhileIdle`, which is the Play-policy-safe choice and must
> stay that way: do NOT switch to exact alarms and do NOT add `USE_EXACT_ALARM`.
> **Context that shapes the design:** the app is being prepared for Google Play, and episode 6
> adds subscriptions (14-day Pro trial, then limited Free). Where a decision now would be
> expensive to undo after purchases exist, prompts 1 and 2 say so explicitly. Run in order: #1 is
> prep (before recording, 10 blocks); **#2 and #3 are the only two on-camera prompts**, which the
> shooting script labels PROMPT 1 and PROMPT 2. Always say "episode", never "day", in anything
> that ends up on screen.

---

## 1. Loose ends sweep  ·  PREP (run before recording)

**Goal:** finish what is already half-built, before the episode adds anything new. Ten
independent blocks. Blocks 1 to 6 finish existing work; blocks 7 to 10 close the holes that only
matter now that the app is heading to Google Play (a loading state wherever something is awaited, a
session that survives a bad signal, reminders that must not outlive the install, and a version
gate). None of this is recorded: the episode only mentions what was adjusted.

**The session secret.** Blocks 8 and 9 touch auth. `AUTH_TOKEN_SECRET` is **already configured** as a
function secret on the auth functions; `auth_refresh` needs the **same value**. Set it from the
AppAmbit **dashboard**, never from the chat and never in a file: it cannot be read back, so a wrong
or whitespace paste fails silently as INVALID_TOKEN on every call. Tell me when to go set it and
wait. Do not print it, log it, echo it or write it anywhere in the repo.

Read CLAUDE.md and DESIGN.md first. Nothing is decided on the phone: any counting or state
change goes through Cloud Code. Cloud Code has no npm packages, no cron and no outbound HTTP.
Keep the frozen names in PLAN.md 1.2. Run `flutter analyze` and `flutter test` after each block
and keep them green. Commit each block separately. Tell me your plan before changing anything,
and wait for my OK.

**Block 1 — Atomic reconciliation (bug, highest priority).**
`ReconcileViewModel` calls `register_ignore` and then `mark_ignored` as two separate Cloud Code
calls. If the app dies, is backgrounded or loses the network between them, the counter has
already been raised but the rows are not marked, so the next reconciliation fetches the same
rows and counts them again: `roast_level` rises twice and the Posture Roast can fire twice for
the same ignored reminder. `register_ignore` is deliberately non-retryable, so there is no
safety net. Replace both calls with one new Cloud Code function
`reconcile_ignored(token, ids, tz_offset_min)` that, in a single transaction, marks those rows
`was_ignored` and applies the ignore count, returning the updated stats row plus how many were
actually counted. Keep the active-window and `paused_until` rules exactly as `register_ignore`
has them today. Write the source to `cloud_functions/reconcile_ignored.mjs` with unit tests for
the window helpers, and add a test proving a repeated call with the same ids is a no-op.

**Block 2 — Notification Center: actions on long press.**
Today the list only opens the break. Add, revealed by a long press on a tile and not before (no
always-visible buttons, no swipe): mark this one as read, mark every one as read, and delete
this one. Use a selection or action sheet that a tap outside dismisses. New Cloud Code
functions: `mark_all_notifications_read(token)` and `delete_notification(token, id)`.
**Critical constraint:** deleting must NOT lose an un-reconciled ignore.
`get_pending_reminders` reads rows `WHERE read = 0 AND was_ignored IS NULL`, so a hard delete of
a still-pending row would silently cancel a punishment the user earned. Make delete a soft
delete (a `hidden_at` column): the row stops showing in the list but `get_pending_reminders`
keeps seeing it.

**Block 3 — Notification Center: show what happened.**
`was_ignored` is written in the database and the app never reads it. Parse it and mark those
rows visually as ignored, in the coral side of the palette. Also: the tile parses `title` and
never paints it, and it shows the raw `pack` value to the user ("14:05 · default"). Decide one
readable layout: use `title` where it helps, and either drop the pack or show a human label for
it.

**Block 4 — Spine Battery.**
The card is five flat bars and a percentage, always coral whatever the charge, so full and dead
look identical. Give it a real battery silhouette (body plus terminal) with the five cells
inside, and a colour that tracks the level: teal at 100 and 80, amber at 60 and 40, coral at 20,
error red at 0. Animate the cell that goes out when the level drops, around 300 ms. DESIGN.md
line 73 asks for a coral container and the code uses the default `Card`: follow DESIGN.md.

**Block 5 — Posture Roast.**
The backdrop is `roastTeal`, chosen so the teal shrimp icon would sit flush, and white text
fails contrast on it (2.10:1), which is why the punishment line ended up near-black. DESIGN.md
and `app_colors.dart` both say the Posture Roast is coral. Repaint it: background
`AppColors.coralContainerDark` (#7A2A18), white text (9.67:1), bright coral kept for accents
only. Do not put white text on #FF6B4A, it is 2.82:1. The mascot is `icon_foreground.png`, the
cheerful launcher icon, while the copy tells the user off. Replace it with a hurt-shrimp asset:
same line work and palette, hunched, eyes squeezed shut, a hand on the lower back, one sweat
drop, silhouette still clearly the same character. Put it in `assets/images/shrimp_hurt.png` and
stop reusing the launcher icon at runtime.

**Block 6 — Text and Home.**
There is not a single `maxLines` or `TextOverflow` in the project, so a long Remote Config line
or a large system font overflows. Do a pass over every screen: cap and ellipsize what must not
grow, let the rest wrap, and check each screen at the largest system text size. `BreaksTodayCard`
shows "2 breaks" and never mentions `daily_goal`, which is the only thing the streak depends on:
show progress against it ("2 of 5"). Home has no pull to refresh while the Notification Center
does: add it. `assets/images` ships 2.2 MB of which only `icon_round.png` is used at runtime;
`icon.jpeg`, `icon_foreground.png` and `icon_launcher.png` are flutter_launcher_icons sources.
Keep them in the repo, out of the bundle. Give the remaining runtime images a `cacheWidth`
matching the size they are actually painted at.

**Block 7 — A loading state everywhere something is awaited.**
Every place that waits on a Cloud Code call or a database read must say so. Audit all 11 views and
every view model mutation. Known gaps: `roast_view.dart` renders the roast line as `?? ''`, so the
screen shows an empty headline while `roast_lines` resolves; `reminder_permission_view.dart` has no
busy state at all while the OS permission request is in flight; `break_view.dart` has a single
indicator and none for the exercise media; the Settings option sheets write through `_update` with an
`isSaving` flag that the sheet itself does not surface. Rules for the pass: a button that triggers a
call becomes disabled and shows progress in place, never a full-screen spinner over a screen that
already has content; a screen with no content yet gets a skeleton or a centered indicator; a screen
that already has content refreshes in place without blanking; nothing waits with a blank or a zero
that looks like real data. Keep it to the shared widgets where you can, rather than one-off spinners
per screen.

**Block 8 — A session that lasts a week and survives being offline.**
Today the token is an opaque string in secure storage with **no expiry stored anywhere**, and
`session_gate_view_model.dart` sends the user to Log In whenever `auth_validate` throws, which
includes "there is no network". So a user with a perfectly valid session is thrown out by a bad
signal. Fix the whole lifecycle:

- **The token already carries its own expiry.** It is an HS256 JWT and the Cloud Code functions read
  `payload.exp` (unix seconds) to reject it. Make `auth_login` and `auth_register` also return
  `expires_at` explicitly in their reply, so the client does not have to parse the JWT to know, and
  set the lifetime to **7 days**.
- Store `expires_at` next to the token in secure storage and keep them in sync: writing one writes
  the other, deleting one deletes the other.
- **Offline start:** on launch, if there is a token and `expires_at` is in the future, let the user
  into the app without calling `auth_validate`. Revalidate in the background when there is network.
  If `expires_at` has passed, go to Log In and clear the token.
- **Only a transport failure is forgiven.** `auth_validate` returning INVALID_TOKEN, or any
  function-level INVALID_TOKEN, ends the session immediately and clears the token. A network error
  does not. Right now both land in the same `catch`.
- **Keep it fresh:** add a Cloud Code function `auth_refresh(token)` that takes a still-valid token
  and issues a new one with a new 7-day window, returning the new token and `expires_at`. Call it on
  app resume when the current token is more than a day old, so an active user never gets logged out,
  and a user who disappears for a week does. Swap the stored pair atomically; if the refresh fails,
  keep using the old token until it actually expires.
- **Say this out loud in your plan so you do not get it wrong:** the device **cannot** verify the
  token's signature, because the signing secret lives only in AppAmbit and must never reach the app.
  The local `expires_at` check decides one thing only — whether to show the app or the Log In screen.
  It is a convenience gate, not a security boundary. **Every data call is still authorized by Cloud
  Code**, which checks the signature and the expiry itself. Do not move any authorization decision
  onto the phone.

**Block 9 — Reminders must not outlive the install.**
Reported symptom: after uninstalling the app, reminders kept arriving. First **reproduce it and tell
me which platform**, because the two behave differently: on iOS, deleting an app removes its pending
notifications, and any notification already sitting in Notification Center stays there until the user
clears it, which is OS behaviour and not a bug. On Android the likely cause is real and it is this:

- **`android:allowBackup` is not declared in `AndroidManifest.xml`, so Android auto-backup is on by
  default.** On reinstall, the Backup Service can restore the app's `shared_preferences`, which is
  where `delivery_log.dart` keeps `notifications.schedule` and where `reminder_preferences.dart`
  keeps its state. A fresh install can therefore inherit a schedule from the previous install and
  start firing reminders again. Worse: `flutter_secure_storage` on Android is backed by
  EncryptedSharedPreferences, so **the session token can survive an uninstall too** and the user
  comes back already logged in. That is a privacy problem on its own and it has to be fixed before
  the store release.
- Fix it: set `android:allowBackup="false"` (and `android:dataExtractionRules` / `fullBackupContent`
  as appropriate for the target SDK) so neither the schedule nor the token is ever backed up. Explain
  in your plan what else that turns off, so I know what I am trading.
- **First run must start clean:** on launch, if there is no token in secure storage, call
  `cancelAll()` on the scheduler and wipe the scheduling preferences before doing anything else. A
  fresh install with no session has no business holding a schedule.
- **Log out must clean up too.** `logOut()` in both `home_view_model.dart` and
  `settings_view_model.dart` cancels the reminders and deletes the token, but leaves the
  `shared_preferences` behind: the delivery log, the reminder preferences and (once blocks 2 and 3 of
  the episode land) the read cache and the outbox. Clear everything that belongs to that user, so the
  next account on the device starts from nothing.
- Add a test that a launch with no token results in zero pending notifications.

**Block 10 — The kill switch: gate a shipped build with no release.**
Once the app is on Google Play you cannot un-ship a build, and waiting for a store review to stop
a broken release is not a plan. This is real code, it just is not worth a camera beat.

- Read `min_supported_version` from AppAmbit Remote Config at start (the config fetch already
  happens in `AppBootstrap` via `enableConfig()`).
- Compare it against the running version. Use `package_info_plus`; it is the one new dependency
  and it is the standard way. Say so in your plan.
- When the running version is below the minimum, show a blocking update screen before anything
  else, in the app's voice, with a button to the store listing. No way around it.
- **Default to permissive:** if the key is missing, unreadable or the fetch failed, the app runs
  normally. A failed config fetch must never lock a user out of their own app.
- One screen and one comparison. Not a feature.

Tests: below the minimum blocks; equal or above runs; missing or malformed key runs; a failed
fetch runs.

---

## 2. Offline first, part one: the app remembers what it saw  ·  on-camera prompt 1

**Goal:** the app opens and shows real content with no network, instead of a spinner and an
error. Today every remote read goes straight to Cloud Code and fails hard when there is nothing
to reach.

Build a cache layer under the existing repositories, in `lib/core/cache/`, on top of
`shared_preferences` (already a dependency — do not add sqflite, hive or drift, and do not add a
connectivity plugin).

- One `CachedRead<T>` helper: try the Cloud Code call; on success store the raw payload and
  return it; on a transport failure (`AuthException` with a transport code, not a function-level
  error like INVALID_TOKEN or NO_SETTINGS) return the stored payload and mark the app offline.
  A function-level error is a real answer from AppAmbit and must keep bubbling up as it does now.
- Wrap these reads: `get_user_stats`, `get_settings`, `get_notifications`, the exercises, the
  sarcasm pack and the roast lines. **Leave `auth_validate` out of this cache:** a session check must
  never be answered from a stored "yes". Offline sessions are handled a different way, already built
  in block 8 of the PREP — the token carries its own `expires_at` and the device reads that. Reading
  the token's own expiry is not the same as caching an answer from AppAmbit; do not blur the two.
- **Key every entry by user id**, not just by function name. A second account logging in on the
  same device must never see the previous user's stats or notifications. Clear that user's
  entries on log out. Namespace the keys with a schema version so a future shape change
  invalidates cleanly instead of crashing on an old payload.
- Render from cache immediately and revalidate in the background, so a warm start paints
  instantly and corrects itself a moment later.
- Add a small "Offline" indicator in the Home app bar, driven by an `isOffline` flag derived
  from the outcome of the last call. No plugin: the network state is inferred from whether calls
  succeed. Show the age of the data when it is stale ("as of 10:42").
- **Reserve one slot now, for episode 6:** the cache must be able to hold an entitlement payload
  with its own freshness policy, because episode 6 adds a 14-day Pro trial and subscriptions,
  and a Pro user on a plane must not lose Pro. Define the slot and a grace period
  (last known entitlement honoured for N days offline, N from Remote Config, default 7) and
  leave it unused today. Do not build purchases, paywalls or entitlement logic in this episode.

Tests: a transport failure returns the cached payload; a function-level error still throws; a
different user id never reads another user's entry; a bumped schema version discards the old
payload without throwing; log out clears that user's entries.

Demo: I put the device in airplane mode and cold start the app. Home paints the Spine Battery,
the streak and Breaks today from cache with the Offline chip showing, and the Notification Center
still lists its history, instead of the error screen we get today. Tell me your plan before
changing anything, and wait for my OK.

---

## 3. Offline first, part two: nothing the user earned gets lost, and the loop holds  ·  on-camera prompt 2

> **Self-contained: paste this whole section, from "Read CLAUDE.md" down to "wait for my OK".**
> Nothing above it is needed.

Read CLAUDE.md and DESIGN.md first.

**State of the code, so you build on it instead of rebuilding it**

- A read cache already exists in `lib/core/cache/` and is wired into the Home, Notifications and
  Settings repositories. It survives offline reads. Use it.
- There is no write queue of any kind. That is what this task adds.
- `reconcile_ignored` already exists and already replaced the old pair of calls
  `register_ignore` + `mark_ignored`. It has a local source in `cloud_functions/`.
- The session already survives being offline: the token carries `expires_at` and `auth_refresh`
  renews it. Do not change any of that.
- Do NOT add a version gate and do not touch `min_supported_version`. That is separate work.
- The working tree has uncommitted work in it. Do not run any git command that discards or
  stages: no reset, no checkout, no stash, no `git add -A`. If you think something needs
  committing, tell me and stop.

**Cloud Code lifecycle.** This task creates and modifies functions, so this applies to every
function you create OR redeploy: create, deploy, wait for the build to be `ready`, activate, add
the HTTP trigger (`set-cloud-function-trigger`, type `http`, slug = function name, enabled), then
remind me to set `AUTH_TOKEN_SECRET` on the **active version** (same value as the auth functions;
it cannot be read back, so a wrong or whitespace paste fails silently as INVALID_TOKEN), then
verify with a real token via MCP: `auth_login`, then call the function, and it must NOT return
INVALID_TOKEN. A missing trigger makes the app's `CloudCode.call` fail with "Something went
wrong"; a mismatched secret makes every token INVALID_TOKEN. Note that `register_break` and
`reconcile_ignored` already exist, and the secret is set **per version** and is **not inherited**
when you activate a new version, so I will have to set it again after you redeploy them. Batch
the pauses: tell me once which functions are waiting on me, not one stop per function.

**No staged failures.** Nothing gets broken on purpose and no bug is provoked to be fixed on
camera. Crash Reporting gets wired correctly, but nothing is crashed. Do not add a test-crash
button, do not suggest one, and do not propose "let's show what happens when it fails" as a demo
beat. Hardening happens in the code; it just is not dramatized.

**Two things I want confirmed explicitly in your plan**

1. Where you generate the `op_id`. It must be **when the user taps Survived**, not when the flush
   runs. If each retry carries a new id, the deduplication is decoration and the break still
   double-counts.
2. The Posture Roast rule, said back in your own words. If your plan does not mention
   `roast_pending`, you have missed the part that matters most.

**Goal:** this is the one that matters. Today a completed 60-second break calls
`register_break` and, with no network, throws: the user did the exercise, held the minute, and
the streak never counts it. The same goes for a reconciliation that cannot reach AppAmbit. Build
the write side of offline, then make sure the whole loop still holds with the cache and the queue
underneath it.

**Note on framing:** none of the hardening below gets dramatized on camera. Nothing is broken on
purpose and no failure is staged. The episode shows the feature working; this prompt just makes
sure it actually does.

### The outbox

Build an outbox in `lib/core/outbox/`, on `shared_preferences`.

- A queued operation holds: a client-generated `op_id` (uuid v4, created when the user acts, NOT
  when the flush runs), the function name, its body, the user id and a created-at timestamp.
  Persist the queue so it survives a kill and a reboot.
- Queue, rather than throw, when a mutation hits a transport failure: `register_break` and
  `reconcile_ignored`. Leave auth, `update_settings` and `auth_change_password` out of the
  outbox: those must stay interactive and tell the user they failed.
- Flush in order, one at a time, on app resume and after any successful call. Stop at the first
  transport failure and keep the rest queued. Drop an operation only on a function-level error
  that will never succeed (INVALID_TOKEN), and surface that as a session end.
- **Server-side idempotency, and get this right because episode 6 depends on it.** Add an
  `op_id` parameter to `register_break` and `reconcile_ignored`, and a table
  `applied_ops(op_id PRIMARY KEY, user_id, function, applied_at)`. Inside the same transaction,
  insert the `op_id` first; if that insert conflicts, skip the mutation entirely and return the
  current stats row unchanged. That makes a replayed flush harmless. Episode 6 will reuse this
  exact mechanism for `grant_entitlement`, where a double-applied purchase is a real problem, so
  build it as a shared helper rather than copy-pasted into each function.
- While something is queued, the UI must not lie. Show the user their break counted, with a
  "waiting to sync" marker on the affected Home card, and reconcile the display when the flush
  lands. Never show a streak increase the cloud has not confirmed: `current_streak` only changes
  on a real response.
- **The Posture Roast must let go of a queued break, and this is not optional.** Right now, offline,
  the roast is a dead end: the only way out is a completed break, the break needs
  `register_break` to reach AppAmbit, and `break_view_model.dart` **swallows that failure on
  purpose** ("Swallowed on purpose: see the doc comment above"), so the user who actually did the
  exercise is silently sent straight back to the roast, forever. Replace that swallow with the
  queue. The rule to apply, and say it back to me in your plan: **release what the user earned by
  doing, hold back what the server computes.** Holding a 60 second timer cannot be faked, so a
  queued completed break clears `roast_pending` locally and lets the user out; `current_streak`
  is computed by Cloud Code against `daily_goal` and `last_break_date`, so it waits for the real
  response. `roastGateProvider` is fed from the stats by `HomeViewModel`, so the locally released
  state has to flow through there and survive a cold start while the op is still queued.
- **A way to replay an applied operation, or the guarantee cannot be shown.** Once a flush
  succeeds the queue is empty, so a second flush does nothing and proves nothing. Add a fourth
  debug row in Settings, inside the existing `kDebugMode` block next to "Fire test reminder
  (5 s)": label `Replay last op (debug)`, subtitle `Debug only. Re-queues the last applied
  operation with its original op_id.` It re-enqueues the last applied operation **with the same
  `op_id`**, so the next flush replays it and the stats row can be seen refusing to move. Keep it
  behind `kDebugMode` like the other three, and make sure it is the real queue path, not a
  shortcut that calls the function directly.
- Update the local sources in `cloud_functions/` for every function you touch.

### Then make the loop hold

With the cache and the outbox in place, finish the hardening the week left open. Report what you
changed, but do not treat any of it as a demo beat.

- **The `roast_pending` race.** Review every path that reads `user_stats`, decides, and writes
  back. `register_ignore`, `register_break` and `reconcile_ignored` must set and clear
  `roast_pending` inside the same transaction that moves the counters, never by a read-then-write
  from a second call. The roast redirect in `app_router.dart` must read the stats the
  reconciliation just applied, not a stale copy. Prove it with a test that interleaves a
  reconciliation and a completed break.
- **Error handlers.** `AppBootstrap.run()` installs none, so framework and async errors go
  nowhere today. Install `FlutterError.onError` and `PlatformDispatcher.instance.onError` and
  route them to AppAmbit Crash Reporting. Check whether the SDK already installs its own and do
  not double-report if it does: tell me what you find before wiring anything.
- **The 17 `catch (_)` blocks.** Audit each one. A fallback that is the designed behaviour
  (Remote Config missing, notifications unavailable) stays, but logs. Anything hiding a real
  failure stops hiding it. List what you changed and why.
- **The copy contradiction.** Three user-facing strings say "server": "Couldn't reach the
  server…", "Unexpected response from the server.", "The server did not return a session token."
  The whole pitch of this backend is that there is no server of your own. Rewrite them to talk
  about reaching AppAmbit, or simply about the connection.
- **Walk the whole loop** with the outbox and the cache in place: sign up, onboarding, a
  reminder, a completed break, an ignored one, the reconciliation, the roast, the streak. Fix
  what breaks and report anything you had to change outside the files above.
- **Android reliability note, not a code change:** reminders use inexact alarms, so under Doze
  they can arrive late. Check whether `grace_window_min` handling tolerates a reminder arriving
  well after its slot, and tell me if it does not. Do not switch to exact alarms.

Tests: a queued op survives a restart; a flush is ordered; a replayed op with the same `op_id`
leaves the stats row untouched and adds no second `applied_ops` row; a function-level error drops the op; the streak never advances
from a queued-only break; the interleaving test above. Run `flutter analyze` and `flutter test`.

Demo: airplane mode on. I open a break, tap Start, 3-2-1, hold the 60 seconds, tap Survived. The
app says it counted and shows "waiting to sync"; the `user_stats` row in the dashboard does not
move. I turn the network back on, the app flushes, and the row moves once: `breaks_today +1`,
`ignored_count 0`, `roast_level` down a step, and `applied_ops` gets exactly one row. Then I tap
"Replay last op (debug)" in Settings and flush again: `applied_ops` still has one row and the
stats row does not move. Then airplane mode again, a completed break, I kill the app from the
task switcher, reopen it still offline and the "waiting to sync" marker is still there. Finally I
walk the loop end to end with the network on, and the dashboard follows along without a single
surprise. Tell me your plan before changing anything,
and wait for my OK.


---

# Episode 6 — Unshrimp starts charging: Pro for 14 days, then the basics

> **Cloud Code lifecycle (applies to every function created or redeployed in this episode).**
> Create → deploy → wait for the build to be `ready` → activate → **add the HTTP trigger**
> (`set-cloud-function-trigger`, type `http`, slug = function name, enabled) → **remind me to set
> `AUTH_TOKEN_SECRET` on the active version** (same value on every function). Secrets are per version
> and are NOT inherited when a new version is activated; they cannot be read back, so a wrong or
> whitespace paste fails silently as INVALID_TOKEN. Then **verify with a real token via MCP**
> (`auth_login`, then call the function; it must NOT return INVALID_TOKEN). Cloud Code deploys are
> single files: no imports, no npm, no outbound HTTP. `node:crypto` is available (the deployed
> functions already use `createHmac` and `timingSafeEqual`).

> **No staged failures.** Nothing is broken on purpose and no bug is provoked to be fixed on camera.
> The limits of the backend (no cron, no outbound HTTP, prices only from the store) are stated up
> front as design constraints. Do not propose a "let's see what happens when it fails" beat.

> **Money rules that every prompt in this episode follows.** Nothing about money is decided on the
> phone: `get_entitlements` in Cloud Code is the single source of truth, compared against the cloud's
> clock, never the device's. Payments always need the network; the App Store does not open a payment
> sheet offline, so the offline outbox from the previous episode is NEVER used for purchases. A
> purchase is not finished in the store until AppAmbit has recorded it; if the network drops between
> the charge and the record, the store delivers the purchase again on the next launch and it is
> recorded once, because the ledger is idempotent by the store's transaction id. Prices are never
> stored in Remote Config or in code: Apple requires the real localized store price. The paywall never
> appears before the onboarding, before the first reminder, during a break or over the roast.

> **What Pro sells.** Reminders, the Posture Roast, the Spine Battery, the streak and today's breaks
> stay free for everyone. Pro unlocks three things: every exercise for the user's pain zone (Free
> always gets the same single exercise for the zone chosen in onboarding), every roast pack (Free
> hears only the default pack), and the stats history (Free sees today only). A subscription: 1.99 a
> month or 14.99 a year, with prices always read from the store. Images only, no video. No ads, ever.

> **State of the app and scope of this episode.** The AppAmbit backend is being recreated on a fresh
> app, so the first PREP stands it back up from the sources in this repository. There are no flavors
> in this episode; they come afterwards. Purchases are shown on **iOS only**, on a physical iPhone, in
> the App Store **sandbox**; Android purchases come after the episode. The iOS bundle id is still the
> placeholder `com.AppAmbit.TestAppSwift` until the account owner confirms the final one; the Android
> `applicationId` is `com.appambit.unshrimp`. The read cache (`lib/core/cache/`) already reserves a
> slot for an entitlement payload and `entitlement_grace_days` (default 7) in Remote Config.
> `_applied_ops.mjs` is the idempotency snippet (insert the `op_id` first inside the same transaction;
> on conflict skip the mutation and return the row unchanged; detect the replay by reading the row,
> never by matching an error message). Run in order: three PREP prompts before recording, then three
> on-camera prompts. Always say "episode", never "day", in anything that ends up on screen.

---

## 1. Stand the backend back up  ·  PREP (run before recording)

**Goal:** a fresh AppAmbit app that behaves exactly like the backend at the end of episode 5, built
only from what is in this repository.

```text
The AppAmbit account behind Unshrimp was deleted and I created a fresh app. Stand the whole backend
back up from this repository, through the AppAmbit MCP, so the app works exactly as it did at the end
of episode 5. Do not change any behaviour; this is a restore, not a feature. Tell me your plan first
and wait for my OK. Stop and ask whenever a step needs something only I can do in the dashboard.

1. Database. Link a database to the new app if there is none, then run docs/backend/schema.sql. Do not
   create the commented purchases table yet. Verify every table and index exists.
2. Cloud Code. Deploy every function in cloud_functions/ except the helpers (_applied_ops.mjs and the
   *.test.mjs files), each through the full lifecycle: create, deploy, wait for ready, activate, add
   the http trigger with slug = function name. Keep a table of name, version, status and trigger.
3. Secrets. After all functions are active, give me the list of functions where I must set
   AUTH_TOKEN_SECRET by hand in the dashboard (same value on all of them). Wait until I confirm.
4. Remote Config. Create the keys documented in the README with their defaults: sarcasm_pack,
   roast_lines (seed from episode 4 in prompts.md), min_supported_version left absent,
   entitlement_grace_days = 7. Do not create the episode 6 keys yet.
5. CMS. Recreate the content types onboarding_questions and exercises with the fields in the README
   and seed them with the same values as the local fallbacks (fallback_onboarding_questions.dart,
   fallback_exercises.dart and assets/dataset/exercises.json), so online and offline content match.
6. App key. Tell me which line of .env to update with the new app key; never print a key.
7. Verify through the MCP with a throwaway user: auth_register, auth_login, save_onboarding,
   get_settings, get_user_stats, register_break with an op_id, the same op_id again (no second
   count), reconcile_ignored. Then delete the throwaway user's rows.

Report a checklist of what exists now. Run flutter analyze and flutter test. Do not commit.
```

---

## 2. The stats history  ·  PREP (run before recording)

**Goal:** the per-day history that Pro will sell, built before the episode and open to everyone for
now. Prompt 1 on camera only puts it behind the gate.

```text
Add a stats history to Unshrimp. Today user_stats only knows today and the current streak; I want one
row per user per day, and a screen that shows the last weeks. Everyone can see it for now; a later
prompt will put the weeks behind Pro. Tell me your plan first and wait for my OK.

The data. A table user_daily_stats(user_id, day, breaks, ignored, goal_met, primary key (user_id,
day)). register_break and reconcile_ignored upsert today's row inside the same transaction that moves
user_stats, reusing their existing op_id idempotency, so a replay never counts twice. day is the
user's local day from the tz_offset_min the functions already receive; goal_met compares breaks with
the user's daily_goal.

The read. A Cloud Code function get_stats_history(token, weeks) that returns one row per day for the
last N weeks (missing days as zeros), plus the best streak and the number of days the goal was met.

The screen. A History screen reachable from Home: today's card on top, then one row per week with a
dot per day (goal met, partial, missed), ignored reminders per week and the best streak. It reads
through the existing read cache so it opens offline with the last thing it saw. Follow DESIGN.md.

Seed for the demo: give me an MCP script, run only when I say so, that fills two weeks of plausible
history for a given user_id, so the screen is not empty on camera.

Cloud Code lifecycle for every function you create or redeploy, as stated at the top of this episode.
Update the local sources in cloud_functions/ and docs/backend/schema.sql.

Tests: a break writes one row for today; the same op_id twice leaves one row; reconcile_ignored
updates ignored on the same row; goal_met flips when breaks reach daily_goal; get_stats_history
returns zeros for missing days. Run flutter analyze and flutter test. Do not commit.
```

---

## 3. iOS ready to buy  ·  PREP (run before recording)

**Goal:** everything on the iOS side that must exist before a sandbox purchase can happen, none of
which is worth a camera beat.

```text
Prepare the iOS side of Unshrimp for in-app purchases in the App Store sandbox. This is setup, not a
product feature. Report block by block and stop whenever a step needs me (an account, a console, a
device).

Block 1, identity. Replace the placeholder bundle id com.AppAmbit.TestAppSwift with the final one I
will give you (proposed com.appambit.unshrimp), in Runner and in RunnerTests. Set the display name to
Unshrimp. Keep automatic signing; tell me where to pick the team in Xcode.

Block 2, capability. Add the In-App Purchase capability to the Runner target.

Block 3, a device build. Tell me the exact steps to run a debug build on my physical iPhone (Developer
Mode, trusting the developer, flutter run on the device), and how to confirm the Sandbox Account
option appears under the App Store settings afterwards.

Block 4, the verification spike in Cloud Code. Deploy a throwaway function named crypto_spike that
parses a PEM certificate with crypto.X509Certificate, checks a certificate against a parent public key
with verify(), and verifies an ES256 signature with crypto.verify using dsaEncoding "ieee-p1363".
Call it through the MCP and report exactly which of the three calls work. This decides whether iOS
receipts are verified by signature (plan A) or shape-checked and deduplicated (plan B). Delete the
function afterwards.

Block 5, what I have to do by hand. A short checklist: the Paid Applications Agreement active, the
app record in App Store Connect with the final bundle id, the subscription group "Unshrimp Pro" with
unshrimp_pro_monthly (1 month, 1.99) and unshrimp_pro_yearly (1 year, 14.99) with an English
localization, a sandbox tester signed in on the iPhone. Mark which ones block the on-camera prompts.

Do not add the purchase plugin yet; that happens on camera. Run flutter analyze and flutter test.
Do not commit.
```

---

## 4. The trial lives in the cloud  ·  on-camera prompt 1

**Goal:** every new user gets everything for 14 days; when it ends, the app drops to the basics with
clear locks and an honest Pro screen; all of it decided in Cloud Code and changed from Remote Config,
with no release.

```text
Add the 14 day Pro trial to Unshrimp, decided entirely in the cloud, with the screens that make it
visible. Nothing about money is decided on the phone. Tell me your plan in two parts, what you create
in the cloud and what you change in the app, and wait for my OK.

The data. Add trial_ends_at, entitlement (pro_trial, pro or free) and pro_until to user_settings. In
auth_register, set entitlement to pro_trial and trial_ends_at to now plus trial_days from Remote
Config, but ONLY when trial_ends_at is null; otherwise the trial would renew on every login and never
end. Remote Config keys: trial_days (14), trial_warning_days (2), trial_warning_text ("Your trial ends
in 2 days. Your spine does not care."), premium_packs (the pack ids that are Pro), pro_product_ids
(the two store ids).

The single source of truth. A Cloud Code function get_entitlements(token) that compares trial_ends_at
and pro_until against the cloud's clock and returns is_pro, entitlement, trial_ends_at, pro_until and
premium_packs. There is no cron in Cloud Code, so the trial expires when it is read, the same
reconcile on open that the roast uses. get_stats_history returns only today when is_pro is false.

The gate. A ProGate that reads is_pro through the existing read cache, using the entitlement slot and
entitlement_grace_days, so a Pro user with no network stays Pro for the grace period. Free gets the
first exercise in the CMS for the user's pain zone, always the same one (deterministic); Pro rotates
through all of them. Free hears only the default pack, in the selector and in the reminder scheduler.
Free sees today's card in History; the weeks are blurred.

The screens. Follow DESIGN.md. All copy in English and never the word "server".
- Home: a status pill under the greeting that opens the Pro screen. "Pro trial · N days left" in
  teal; "Trial ends in 2 days" in amber when 2 days or fewer are left; "Free plan · See Pro" when
  free; "Pro" when Pro.
- Locks where each Pro thing lives, not a wall: under the break's exercise a row "More exercises for
  your neck · Pro" (use the user's zone); premium packs in Settings with a lock; History weeks
  blurred with "Unlock your history · Pro". Tapping a lock opens the Pro screen. Never interrupt a
  break in progress.
- The Pro screen: title "Unshrimp Pro"; the trial line ("Your trial ends Oct 29" or "Your trial
  ended"); three benefit rows, all exercises for your pain zone, every roast pack, your full history;
  one honest line "Free keeps reminders, the Posture Roast, the Spine Battery and your streak.";
  monthly and yearly plan cards whose prices will come from the store (until the next step, show
  "Loading prices from the App Store" and never a number); a Start Pro button and Restore purchases
  that do nothing yet; links to Terms and Privacy.
- When the trial has ended, on the next open: a bottom sheet, shown once, "Your Pro trial ended",
  listing what stays and what is now Pro, with "See Pro" and "Continue free". It is not a wall.
- A local notification trial_warning_days before trial_ends_at with trial_warning_text, scheduled the
  same way reminders are.
The Pro screen never opens on its own before the onboarding, before the first reminder, during a
break or over the roast.

Cloud Code lifecycle for every function you create or redeploy, as stated at the top of this episode.
Update the local sources in cloud_functions/ and docs/backend/schema.sql.

Tests: a new user is born pro_trial with trial_ends_at = now + trial_days; logging in again does not
reseed; trial_ends_at in the past reads as free; pro_until in the future reads as pro even if the
trial is over; the Free picker is deterministic and the Pro picker rotates; premium packs are
filtered for Free; get_stats_history returns only today for Free; the ended sheet shows once; the Pro
screen never opens before onboarding. Run flutter analyze and flutter test.

Demo: I sign up a new user and Home shows "Pro trial · 14 days left" with everything open. I open the
user_settings row in the dashboard and set trial_ends_at to yesterday. I reopen the app: the "Your
Pro trial ended" sheet appears once, I continue free, and the break shows the same exercise with the
locked row under it, Halloween is locked, History is blurred, and any lock opens the Pro screen. Then
I change trial_days to 7 in Remote Config and sign up another user: born with 7 days, no release.
Tell me your plan before changing anything, and wait for my OK.
```

---

## 5. Connect the App Store, in the sandbox  ·  on-camera prompt 2

**Goal:** the app talks to the App Store: the Pro screen shows the real store prices, in the sandbox.
Short and visual; the purchase itself is the next prompt.

```text
Connect Unshrimp to the App Store, in the sandbox, so the Pro screen shows the real store prices.
iOS only for now. Tell me your plan first and wait for my OK.

Add in_app_purchase, the official Flutter plugin, with StoreKit 2 enabled on iOS. Check the current
version and the exact name of the StoreKit 2 switch before using them; do not guess. Read the product
ids from pro_product_ids in Remote Config and ask the store for unshrimp_pro_monthly and
unshrimp_pro_yearly. On the Pro screen, show each plan with the localized price the store returns,
and mark the yearly plan as the better value only with a saving computed from the two store prices.
If the store returns nothing, show "Plans are unavailable right now." and never a number. Wire
Restore purchases to the store's restore call and only log what comes back; recording it is the next
prompt. On debug builds, show a small "Sandbox" tag on the Pro screen so it is obvious on camera
that no real money moves. Start Pro still does nothing.

Tell me exactly what I have to do by hand before the demo (the sandbox account on the iPhone, the
capability in Xcode), and keep anything with an account, an email or a key off the screen.

Tests: products are requested with the ids from Remote Config; no price is hardcoded anywhere;
an empty response shows the unavailable message. Run flutter analyze and flutter test.

Demo: on my iPhone, signed in with the sandbox tester, the Pro screen shows Monthly and Yearly with
the App Store prices and the Sandbox tag. Tell me your plan before changing anything, and wait for my
OK.
```

---

## 6. The purchase, verified in the cloud  ·  on-camera prompt 3

**Goal:** the user pays in the App Store sandbox, Cloud Code verifies the receipt with `node:crypto`
alone, writes it to a ledger, and turns the user Pro. The same receipt twice changes nothing: the
idempotency of episode 5 again, now with money.

```text
Wire the purchase into Unshrimp on iOS, and make the cloud the only thing that decides who is Pro.
Tell me your plan first and wait for my OK. Two things I want confirmed explicitly in your plan: where
the purchase is finished in the store (it must be after AppAmbit answers OK, never before), and what
key makes grant_entitlement idempotent (the store's transaction id, plus the op_id from applied_ops).

The constraint that shapes everything: Cloud Code has no outbound HTTP, so it cannot call Apple. It
does have node:crypto. StoreKit 2 gives the phone a JWS signed by Apple with the certificate chain in
the x5c header. Verify the chain up to the Apple Root CA G3 certificate embedded as a constant in the
function, then the ES256 signature with the leaf key, and read bundleId, productId, transactionId,
originalTransactionId, purchaseDate, expiresDate and environment. Reject a bundleId that is not ours.
If the crypto spike from the PREP showed that X509Certificate is not available, use plan B: validate
the shape (bundle id, product id, dates) and deduplicate by transactionId without a cryptographic
check, and say so in a comment at the top of the function.

The ledger. A table purchases(id, user_id, store, product_id, transaction_id UNIQUE,
original_transaction_id, environment, purchased_at, expires_at, raw_payload, status, created_at).

The functions.
- grant_entitlement(token, store, product_id, payload, op_id): in one transaction, insert the op_id
  into applied_ops first (the snippet from _applied_ops.mjs, inlined), verify the receipt, insert the
  purchases row (if the transaction_id already exists, insert nothing and change nothing), then set
  entitlement to pro and pro_until to expiresDate. A purchase during the trial makes the user pro.
  Return the same object as get_entitlements.
- restore_entitlement(token, store, payloads[]): verify each active purchase the store reports and
  recompute pro_until from the latest one. A purchase belongs to the store account, not the Unshrimp
  account: if an original_transaction_id is already bound to another user_id, reject it with
  PURCHASE_OWNED_BY_ANOTHER_USER and change nothing. With no outbound HTTP the cloud cannot be told
  about renewals or cancellations, so the app sends what the store says is active on every launch and
  pro_until follows it.

The app. Start Pro calls the store; on purchased or restored, send the JWS to grant_entitlement with a
fresh op_id generated at the tap. Only when AppAmbit answers OK, complete the purchase in the store,
then refresh get_entitlements and the gate. If AppAmbit fails, do NOT complete it: the store delivers
it again on the next launch and the same transaction id is recorded once. A purchase attempt with no
network shows a plain message; it never queues. On every launch and on Restore purchases, send the
store's active purchases to restore_entitlement.

Cloud Code lifecycle for every function you create or redeploy, as stated at the top of this episode.
Update the local sources in cloud_functions/ and docs/backend/schema.sql.

Tests: a valid receipt grants pro and writes one row; a tampered payload is rejected with
INVALID_RECEIPT and changes nothing; the same transaction_id twice leaves one row and the same
pro_until; the same op_id twice is a no-op; a purchase during the trial sets pro; expiresDate in the
past reads as free; restore with another user's original_transaction_id is rejected; the app does not
complete the purchase when grant_entitlement fails. Run flutter analyze and flutter test.

Demo: on my iPhone, the user whose trial I expired opens the Pro screen, taps Monthly, Start Pro, and
confirms in the sandbox sheet. The pill turns to Pro, the exercises rotate again, Halloween is back
and History shows the weeks. In the dashboard, user_settings says pro with a pro_until and purchases
has exactly one row. Then I tap Restore purchases: the same receipt comes back and purchases still
has one row. Tell me your plan before changing anything, and wait for my OK.
```

---

## After this episode (not run yet)

These are planned and intentionally left out of the episode:

- **Flavors** dev, stage and prod, so the production app rejects sandbox receipts and the test app
  accepts them.
- **Android purchases**: Play Billing with a license tester, the receipt verified with the Play
  license public key (RSA) in the same `grant_entitlement`.
- **More to sell**: more exercises per zone, more lines and roast packs, all from the CMS and Remote
  Config, with no code change.
- **Production**: the subscriptions submitted for review with an app version, Terms and Privacy
  published.
