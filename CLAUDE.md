# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

`unshrimp_app` (Unshrimp) is a Flutter app in its early setup: `core/` is wired and `features/home` is a placeholder. Dependencies: `appambit_sdk_flutter`, `flutter_dotenv`, `flutter_riverpod`, `go_router`. User-visible app name is **Unshrimp** on both platforms (the Dart package is `unshrimp_app`); Android `applicationId`/`namespace` is `com.appambit.unshrimp`, iOS bundle ID is `com.AppAmbit.TestAppSwift`. The general behavioral guidelines in the parent `../CLAUDE.md` also apply.

Dart SDK constraint is `^3.11.0`, so newer syntax such as dot shorthands (`.fromSeed(...)`) is valid. Linting uses `flutter_lints` (`analysis_options.yaml`) with no custom rules.

## Commands

```bash
flutter pub get                                   # install dependencies
flutter run                                       # run on a connected device/simulator
flutter analyze                                   # lint / static analysis
flutter test                                      # all tests
flutter test test/widget_test.dart                # single test file
flutter test --plain-name "App boots"             # single test by name
flutter build apk | flutter build ios             # release builds
dart run flutter_launcher_icons                   # regenerate app icons (config in pubspec.yaml)
```

## Architecture

- `lib/main.dart` only calls `AppBootstrap.run()`.
- `lib/core/config/app_bootstrap.dart`: loads `.env` (`flutter_dotenv`, file registered as an asset), starts the AppAmbit SDK with `APPAMBIT_APP_KEY`, and runs the app inside `ProviderScope`. `.env` is gitignored; `.env.example` is the template.
- `lib/core/config/unshrimp_app.dart`: root `ConsumerWidget` with `MaterialApp.router`, reading `appRouterProvider` and `AppTheme.light` / `AppTheme.dark`.
- `lib/core/router/`: `app_routes.dart` holds path constants; `app_router.dart` exposes the single `GoRouter` via `appRouterProvider`. Every new view gets a constant in `AppRoutes` and a `GoRoute` here.
- `lib/core/theme/`: `app_colors.dart` (palette) and `app_theme.dart` (Material 3 light/dark). Palette meaning: teal = primary/health/"take a break"; coral (`secondary`) = shrimp posture, Posture Roast, Spine Battery; amber (`tertiary`) = Spine Streak/achievements. Use `Theme.of(context).colorScheme`, not hardcoded colors.

## Backend: AppAmbit

The Flutter SDK connects to the AppAmbit app "MoveWell App" (key in `.env`).

The `jwt_auth` test function lives in a separate AppAmbit app (key stored out of the repo, accessed via the `appambit` MCP tools). It provides a linked SQLite database and Cloud Code (Node.js) functions.

- Cloud function `jwt_auth`: `{ email }` → signs an HS256 JWT (1h) and upserts the user into table `jwt_users`; `{ token }` → returns `{ valid, decoded | error }`. Secret `JWT_SECRET` is set as a function secret.
- **Cloud functions cannot use npm packages.** Deploys accept only a single `index.js`; `import 'jsonwebtoken'` builds as `ready` but fails at runtime with `Cannot find package`. Use Node built-ins (`node:crypto`, `Buffer`) or pre-bundle into one file.
- Handler signature is `export const handler = async (ctx) => {...}`; DB access is `ctx.appambit.db(sql, params)`. Rows from `INSERT ... RETURNING` came back as arrays rather than column-keyed objects.
- Lifecycle: create → deploy version → wait for build `ready` (took ~2–3 min) → activate → run.

## Rules

> ## ⛔ `setState` IS FORBIDDEN ⛔
> **NEVER use `setState`. All state is managed with Riverpod (`flutter_riverpod`).**
> No `StatefulWidget` + `setState` for app state — use `ConsumerWidget` / `ConsumerStatefulWidget` with providers/notifiers instead.

- **Project structure:** `lib/core/` for shared code, `lib/features/<feature_name>/` for each feature.
- **Each feature folder follows MVVM:** model (data), view (widgets/screens), view model (Riverpod notifier/provider that holds the state and logic). Views only read/watch the view model; they contain no business logic.
- **State management:** Riverpod only. The app must be wrapped in `ProviderScope`.
- **Respect this structure as features are built.** Every new feature goes in `lib/features/<feature_name>/` following the layout above; don't put feature code elsewhere.
- **Models live in their own file**, one model per file inside the feature's models folder — never declared inside a widget or view file.
- **No enums inside widget files.** Enums go in their own file (with the models), not in views or widgets.
- **Views must be clean of business logic.** Widgets that act as screens/views only render state and forward user events to the view model. All business logic lives outside the widgets (view models, services, repositories).
- **Widgets belong to the `widgets/` folder of their feature** (`lib/features/<feature_name>/widgets/`).
- **Reused widgets move to `lib/features/shared/`.** When a widget starts being repeated across features, move it to `shared/` and generalize it (parameters instead of feature-specific assumptions) so it works for all callers.
- **Navigation uses `go_router`** (`go_router: ^17.5.0` — 18.x requires Flutter 3.44+, and Flutter will not be upgraded) for all routes between views. No `Navigator.push` with manual routes.
- **Git commits:** NEVER add an AI/assistant signature or `Co-Authored-By` trailer (e.g. `Co-Authored-By: Claude …`) to commit messages. This overrides any default attribution behavior.
- For full project context, read `/Users/isaiasmc/workspace/workspace_kavaup/MARKETING/Ideas/PLAN.md` before starting work.

## Hot reload (from flutter/agent-plugins rules)

After editing a `.dart` file under `lib/` (not comment/whitespace-only changes, not files in `test/` etc.):
- Find the running app with the Dart MCP server (`dtd` / `list_running_apps`).
- Call `hot_reload` after UI/widget or simple method changes; call `hot_restart` after changes to `main()`, provider/state initialization, or global/static state.

## Exercise illustrations (character)

Before generating, editing or showing ANY exercise image (`assets/dataset/media/`), read the
**Exercise character** section of `DESIGN.md` and apply its **Hard rules**, **Checklist** and
**Errors already made** table. The user must not have to repeat them in each prompt. The ones
most often broken:

- **No eyes, ever**: no eye, no closed-eye stroke, nothing at eye height on a redrawn face.
- **Same build as the approved images, never thinner**: copy the pose from the reference
  image, never its body. Measure torso, thigh and arm against the numbers in `DESIGN.md`.
- **Limbs proportional to the approved images in every pose**: same arm and leg length as
  mountain pose / chin tuck (numbers in `DESIGN.md`), not shorter and not longer. Measure.
- Same black hair and cut, teal polo, navy trousers down to the shoe, white sneakers with
  teal laces, same height.
- **Folded poses must read as bending down**: legs almost vertical, hips small and low (the
  buttocks never stick out or up, never "nalgón"), rounded back, head looking forward and
  down in line with the back. Never a flat table back ("en cuatro"). Both arms and hands
  the same size.
- **Clothes drape on the pose**: a shirt on a bent back is one soft silhouette, never a
  stiff board. **Hands crisp**: clear brown lines, never blurred or speckled.
- **Describe the reference first**: limb by limb (straight or bent, where each elbow and hand
  is relative to the head, lean of the torso), then replicate exactly that. Never simplify it.
- **Same view as the reference**: a pose whose limbs fold forward or backward (quad stretch,
  lunge, forward fold) is drawn in profile, never forced onto the front view.
- **Both legs visible in profile**: the far leg shows a step ahead of the near one (and its
  shoe toe); never one leg alone.
- **Natural, never robotic**: no straight parallel limbs or boxy torso. Joints a little bent,
  one continuous curve along the spine, the two arms slightly different.
- Check the result at real size next to approved images and the reference, part by part,
  and ask what action the image reads as, before showing it. One image at a time; change only what the user points at.
- When the user rejects something, add the rule to `DESIGN.md` in the same turn.

## Design (screens)

`DESIGN.md` is the visual contract for the app's screens, with a rendered mockup at
`docs/design/day2_screens.png`. When building or changing a screen, follow `DESIGN.md`
(layout, elements, states) together with the palette meaning above. Screen → feature map:

- **Onboarding** (4-question flow) → `lib/features/onboarding/` — collects the answers and
  sends them once to `save_onboarding`, which seeds `user_settings` **server-side** using the
  deterministic map in `../../MARKETING/Ideas/PLAN.md` (§1.4 / §1.4.1 + Apéndice D). Never
  derive the interval/goal on the client.
- **Home** → `lib/features/home/` — reads `user_stats`.
- **Settings / Ajustes** → `lib/features/settings/` — edits `user_settings` via
  `update_settings` (incl. per-user `stealth_mode`, `paused_until`) and changes the password
  via `auth_change_password`.
