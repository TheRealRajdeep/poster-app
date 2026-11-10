# Replays

Each `*.json` file here is one render case: a spec + the exact user inputs.
`replay_test.dart` renders every case with the real bundled fonts and compares
the **layout** (font size, line count, overflow per text slot) with
`_snapshots.json`. Layout is platform-independent, so the same snapshot holds
on Windows, Linux CI and Android.

## Turning a bug report into a replay
1. Save the poster's `spec.json` (or point at an existing fixture).
2. Add `<short-name>.json`:
   ```json
   {
     "spec": "path/to/spec.json (relative to packages/poster_renderer)",
     "language": "kn",
     "texts": { "self.name": "…", "greeting": "…" },
     "photos": { "self": [600, 900] }
   }
   ```
   `photos` gives placeholder cut-out sizes (width, height). Optional `"scene"`
   points at a real scene image; otherwise a flat colour is used.
3. Run `UPDATE_SNAPSHOTS=1 flutter test test/replay_test.dart`, check the diff
   in `_snapshots.json` is what you expect, then fix the bug: the snapshot
   change becomes the regression test.
