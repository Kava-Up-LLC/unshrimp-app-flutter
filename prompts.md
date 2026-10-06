# Day 1 — Account System with Cloud Code (Sign Up, Log In and Session)

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

# Day 2 — Onboarding that Personalizes + Settings (CMS + per-user Database)

> Home was already built on Day 1. Day 2 adds the Onboarding and Settings features and the
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

Content type `exercises` — short break exercises keyed by pain zone (used later in Day 3),
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

# Day 3 — Local Reminders + 60s Micro-Break + Notification Center

> State of the app (verified in code): Cloud Code functions that already exist and are called with
> `CloudCode.call('name', body: {...}).future`: auth_register, auth_login, auth_validate,
> save_onboarding, get_settings, update_settings, auth_change_password, get_user_stats. CMS content
> type `exercises` (fields zone, title, steps) is read with `AppAmbitCms.content('exercises')...getList()`.
> The app does NOT yet use Remote Config, Analytics, flutter_local_notifications, or a `notifications`
> table. All app copy is in English. Day 3 adds the local reminder engine, the 60s break, and the
> Notification Center. Run these in order: #1 is prep (done before recording); #2 to #4 are the on-camera prompts, which the shooting script / script_time.txt label PROMPT 1, 2 and 3.

## 1. Update the exercise data — media + office set  ·  PREP (run before recording)

**Goal:** give every break exercise a picture/gif and replace the CMS catalog with the curated office
set in `assets/dataset/`, keeping all five pain zones covered. Prep for the 60s break screen.

```text
Update the MoveWell exercise data end to end. The 60s break screen (built next) needs a picture per exercise.

Source of truth: the folder assets/dataset/ in this repo (already in place). It has exercises.json (13 office stretches with zone, title, steps and media paths) and media/ (a <id>.gif and a <id>-main.webp for each). The data and images come from RepDB free tier, so you MUST also add a visible credit "Exercise data by RepDB (repdb.co)" on the app's About/credits screen.

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
that is allowed to be empty (null for now, used in Day 4). List the table to confirm it exists.

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

# Day 3 — Follow-up prompts (in the order they were sent)

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
Leaving register_break out is correct, that's Day 4. For Day 3 the proof is the break_completed event in Analytics. Proceed: flutter analyze + flutter test, wire the tap + the Home "Take a break now" button, and after I sign in, open Analytics (Events) to show break_started and break_completed.
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


# Day 4 (Episode 4) — Ignored Reminders + Posture Roast + Streak & Spine Battery

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
