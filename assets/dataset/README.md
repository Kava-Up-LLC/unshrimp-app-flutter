# Unshrimp exercise dataset (office / desk posture breaks)

Office-appropriate stretches for the Unshrimp/ShrimpFix break screen. **Every exercise
is done standing or seated in a chair. No floor, mat, or lying poses.** Grouped by the
app's zones (`neck`, `shoulders`, `lower_back`, `wrists`, `none`).

## Files
- `exercises.json` - the records (title EN/ES, steps, instructions EN/ES, difficulty, media paths, source/attribution).
- `media/<id>.gif` - animated demo.
  - `gif_type: "twopose"` -> real 2-position movement (built from the source start/peak frames).
  - `gif_type: "breathing"` -> single hold pose with a subtle breathing zoom (source ships one pose for most stretches).
- `media/<id>-main.webp` (or `-start.webp` / `-peak.webp`) - clean still illustration(s), 512x512.

## Coverage notes (important)
RepDB's free tier is yoga/gym heavy, so the office-appropriate subset is small (~13). Known gaps:
- **wrists**: not covered (RepDB only has a kneeling floor version). Use the app's own wrist-stretch steps.
- **seated-in-chair** twists / shoulder shrugs / neck rolls are not available as clean chair illustrations here.
- `app_registered_as` in each record marks exercises that map to the 10 already registered in the app.

## Source & license - IMPORTANT
Images and exercise data: **RepDB free tier** (https://repdb.co · https://github.com/RepDB/exercise-dataset).
- Free for **commercial IN-APP use** with visible attribution.
- **You must show** `Exercise data by RepDB (repdb.co)` in the app's about/credits screen.
- Do **not** republish this folder as a standalone dataset / API (in-app use only).
- Images may be resized/cropped/recolored; do **not** feed them to generative AI.
- GIFs here are built locally from the free static frames (allowed resize/crop transform), NOT from RepDB's paid preview animations (those are evaluation-only).
