# Unshrimp exercise dataset (office / desk posture breaks)

Office-appropriate stretches for the Unshrimp/ShrimpFix break screen. **Every exercise
is done standing or seated in a chair. No floor, mat, or lying poses.** Grouped by the
app's zones (`neck`, `shoulders`, `lower_back`, `wrists`, `none`).

## Files
- `exercises.json` - the records (title, steps, instructions, difficulty, media paths).
- `media/<id>.gif` - animated demo.
  - `gif_type: "twopose"` -> real 2-position movement (built from the start/peak frames).
  - `gif_type: "breathing"` -> single hold pose with a subtle breathing zoom (one pose for most stretches).
- `media/<id>-main.webp` (or `-start.webp` / `-peak.webp`) - clean still illustration(s), 512x512.

## Coverage notes (important)
The office-appropriate subset is small (~13). Known gaps:
- **wrists**: not covered. Use the app's own wrist-stretch steps.
- **seated-in-chair** twists / shoulder shrugs / neck rolls are not available as clean chair illustrations here.
- `app_registered_as` in each record marks exercises that map to the 10 already registered in the app.

## Source & license
Exercise data and images are **Unshrimp's own** (the illustrations are generated in-house).
Free to use and ship inside the app.
