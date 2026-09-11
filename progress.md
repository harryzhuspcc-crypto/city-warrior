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

## Steps 4–5 session

- Started the Step 4–5 implementation audit and replaced the completed Steps 1–3 task plan with the current work plan.
- Confirmed that movement/input scaffolding exists but Y sorting, boundaries, and jumping do not.
- Confirmed that combat is currently duration-only scaffolding and requires full `AttackData`, hitbox, damage, deduplication, and finite-buffer integration.
- Completed the required Godot movement/composition/resource/combat/input/testing guidance review with three independent architecture/test audits.
- Fixed the implementation contracts for jump ownership, boundary/Y-sort scene structure, the exact 5/3/10 punch timeline, facing snapshots, and an eight-frame input buffer.
- Added `tools/smoke_test_steps_4_5.gd` covering the level contract, independent jump arc, exact combat phases, hitbox state/facing, damage deduplication, and buffer expiry.
- Captured the expected red baseline: the test reports the missing Step 4–5 scene/classes/APIs before implementation.
- Implemented `JumpComponent` with deterministic height/velocity simulation, ground-position tracking, visual-only lift, rejection while airborne, exact landing clamp, and jump/land signals.
- Added jump stats and K input integration while preserving movement on the belt-scroller ground plane.
- Added a minimal `PrototypeAlley` main scene with four world-layer boundaries and a direct-child Y-sorted `Actors` container.
- Added and passed `STEP_4_SMOKE_TEST_PASS`, including Y-sort, jump independence, airborne depth movement, clean landing, and all four collision boundaries.
- Added `billy_punch.tres`, generic `HurtboxComponent`, and a data-driven `CombatComponent` with exact 5/3/10 phases, active-only hitbox state, facing-latched geometry/knockback, and per-attack target deduplication.
- Replaced indefinite attack input storage with an eight-frame countdown buffer; tests cover final-valid-frame consumption, expiry, early-buffer rejection, and late-recovery chaining.
- Added a real physics-backed Area2D overlap smoke test. Player, Step 4, combined Steps 4–5, and overlap smoke tests all pass.
- Final Godot editor import and main-scene run exit 0 with no diagnostics; requirement scans find no stale duration property, gameplay Timer, or gameplay `await`.
- Independent completion audit accepted timing, buffering, collision masks, resource isolation, and jump/depth separation, but blocked sign-off on physics-safe lethal cancellation and true horizontal feet-pivot alignment.
- Added the lethal-overlap regression and made attack cancellation defer physical hitbox changes when invoked during a physics frame; regression passes with no query-flush diagnostics.
- Began feet-pivot extraction improvements and tightened overlapping punch/hurt crops; fixed a strict-shell newline failure in ImageMagick metadata reads.
- Regenerated all Billy frames with deterministic floor-contact midpoint alignment at x=40 and bottom y=80; final contact-sheet review found no crop artifacts or clipping.
- Added an automated per-frame 80×80 floor-contact pivot audit to the Step 4 smoke test.
- Expanded feet detection to eight lower rows so both boots influence wide stances, corrected three truncated crop rectangles, and added a regression rejecting any opaque pixels touching the horizontal canvas edges.
- Re-extraction, Godot import, automated feet-pivot audit, and final visual contact-sheet inspection all pass.
- Added the diagnostic-aware smoke-test runner; all four suites pass through it.
- Final independent sign-off audit confirms Steps 4 and 5 complete with no blockers or high/medium requirement gaps.
- Sign-off rerun: all four diagnostic-aware smoke suites pass, the prototype-alley main scene exits cleanly, and no Godot ERROR/WARNING diagnostics are present.

## Jump correction session

- Reviewed all four user references with native image input.
- Scoped this pass to the basic two-pose jump and deferred kick/combo implementation until after the enemy/fighting loop.
- Captured a deterministic red regression: `STEP_4_SMOKE_TEST_FAIL: Billy is missing the referenced jump animation`.
- Image matching libraries are unavailable and the references are resampled, so source-frame location is proceeding through ImageMagick/visual sheet inspection.
- Located the exact two requested jump poses on Billy's source sheet and excluded the adjacent attack pose.
- Added two clean jump frames and a non-looping `jump` SpriteFrames animation.
- Updated player presentation so ascent uses the first reference pose and descent uses the second; jump physics and depth sorting remain unchanged.
- Persisted all supplied references and documented the deferred kick and hit-confirmed punch/kick combo rules in the development plan.
- The focused jump regression now passes and the generated jump contact sheet matches the reference visually.
- Final sign-off: idempotent extraction, Godot import, all smoke suites, and main-scene run pass with zero diagnostics; no debug tags remain.

## Facing correction session

- Reviewed both supplied screenshots: desired neutral retains the prior locomotion view; current neutral resets to generic front idle.
- Captured the exact red regression at `Up-left movement must face left`.
- Removed vertical-walk flip suppression and added persistent last-locomotion view handling; the focused player smoke test is green.
- Full extraction/import/test/main run is green; the first cleanup command falsely flagged literal failure-handler strings in test source, requiring a corrected log-only diagnostic scan.
- Corrected sign-off passes all four suites and the main scene with zero runtime diagnostics or debug instrumentation.

## Jump-height and kick session

- Reviewed the supplied basic-kick reference and scoped implementation to the non-combo two-pose kick.
- Defined the control migration: J punch, L kick, grab retained without an L binding.
- Captured red tests for the 25.50 px low apex and missing kick action, then located both exact kick poses in the Billy source sheet.
- Increased Billy's takeoff speed to 252.4 px/s; the focused Step 4 test now passes a constrained 50–52 px apex while retaining the existing gravity and ground-plane model.
- Extracted and visually verified the exact two kick poses.
- Added `billy_kick.tres` (6 startup, 4 active, 12 recovery, 15 damage), generalized `CombatComponent` to latch requested attack data, and wired L input through player presentation.
- Updated project configuration and the long-term plan so basic kick is implemented while hit-confirmed combos remain deferred.
- Focused player smoke now passes L binding, kick frame count, kick selection, animation, and completion.
- Added deterministic chamber/extension synchronization to kick startup/active timing.
- Expanded physical and buffer regressions for kick damage deduplication, expiry, and buffered punch-to-kick chaining; all four suites pass.
- Independent audit blocked sign-off on airborne invisible attacks and input-latching/priority edge cases; adding focused regressions before correction.
- Added an eight-frame jump buffer, blocked ground attacks while airborne, and made punch/kick queues mutually exclusive with latest-input priority. Both focused regressions are green.
- Reordered landing/eligibility safely and added event-capture guards; final pre-landing jump buffering and real same-tick attack ordering regressions now pass.
- Final sign-off rerun passes extraction, idempotent configuration, Godot import, all four smoke suites, physical kick overlap, and main-scene startup with zero diagnostics.
