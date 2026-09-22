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
