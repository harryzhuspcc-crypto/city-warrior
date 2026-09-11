# Progress Log

## Session

- Loaded the Godot architecture, composition, animation, combat, and input guidance.
- Inspected the empty project and all downloaded source sheets.
- Confirmed the source sheets sit outside `res://` and require copying into the project.
- Confirmed the installed Godot executable.
- Started Phase 1.
- Inspected enlarged top and bottom halves of the Billy sheet and selected source rows for the minimal animation set.
- Mapped the source row for the first punch and identified candidate hurt/knockdown rows.
- Generated the first transparent 80×80 frame set and visually audited a contact sheet; began tightening crop bounds to remove neighboring fragments.
- Godot imported all generated resources and registered all typed scripts successfully.
- The first headless scene run exposed missing persisted InputMap actions; runtime action mutation did not serialize them as expected.
- Tightened the generated frame crops and removed neighboring-sprite fragments.
- Completed the feature folder structure and typed stats, health, movement, combat, input, state, and visuals scripts.
- Created `billy_sprite_frames.tres`, `billy_stats.tres`, and `player.tscn`.
- Persisted keyboard actions and pixel-art display settings in `project.godot`.
- Re-imported and ran the main player scene headlessly with zero diagnostics.
- Corrected the Godot 4.7 animation sync API and synthetic-input test timing.
- Player smoke test now passes movement, attack entry, attack completion, and return-to-idle checks.
- Completed a final visual contact-sheet audit of all generated animation frames.
- Final audit: 13 source sheets, 16 generated 80×80 RGBA frames, six animation groups, eight input actions, and zero unintended source-sheet import artifacts.
- Final idempotent extraction, configuration, Godot import, main-scene run, and player smoke test all exited 0 with no diagnostics.
- Steps 1–3 are complete.
- Directional walking regression: reproduced the always-rear-facing bug with a red smoke test.
- Split walking into `walk_side`, `walk_up`, and `walk_down`, using dominant-axis selection in `PlayerVisuals`.
- Visually corrected side-frame crops to remove source-sheet annotations and neighboring pixels.
- Final Godot import, main-scene run, and directional regression smoke test all pass with zero diagnostics; each directional walk animation contains four frames.
- Updated Left/Right and horizontal-dominant diagonals to use `walk_down`; only upward-dominant input uses `walk_up`. Removed the unused `walk_side` asset set. Final regression test passes.
