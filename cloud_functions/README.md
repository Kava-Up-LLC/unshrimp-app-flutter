# Cloud Code sources (AppAmbit "MoveWell App")

Canonical source for the app's Cloud Code functions. They run on AppAmbit, not
in the Flutter app; deploy is via the `appambit` MCP (`deploy-cloud-function-version`
→ wait for build `ready` → `activate-cloud-function-version`), so the deployed
code must stay in sync with these files by hand.

Each function is a single self-contained ESM file exporting `handler` (Node
built-ins only — no npm packages at runtime). `register_ignore.mjs` also exports
its pure window helpers so they can be unit-tested.

Run the helper unit tests (Node 18+, outside `flutter test`):

```bash
node --test 'cloud_functions/**/*.test.mjs'
```

Secrets (e.g. `AUTH_TOKEN_SECRET`) are set per function in the AppAmbit
dashboard, never in these files.
