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

## Four special-moves session

- Loaded the required Godot composition, state, CharacterBody2D, resource, combat, animation, and input guidance.
- Reviewed and persisted all four supplied move references.
- Extracted each reference pose independently and matched its binary silhouette to exact coordinates in `billy-lee.png`.
- Defined grounded chord priority, airborne jump-kick behavior, 12-frame same-direction double-tap recognition, rear-facing hit geometry, back-kick facing reversal, and an unchanged jump-height contract.
- Started Phase 1 regression work.
- Captured the expected red baseline: back kick no longer remained ACTIVE during descent.
- Added `finishes_on_landing` and `landing_hold_frame` AttackData fields to both aerial kicks.
- Updated CombatComponent to hold extension frame/ACTIVE hitbox while airborne and finish naturally on landing; Player supplies JumpComponent's current airborne state.
- Strengthened special-move regressions verify descent state, active hitbox, held pose index 3, no early back-kick reversal, exact landing completion, and the unchanged jump trace. All five suites pass.
- Added held-contact deduplication, no-post-landing-hit, death-cancellation, startup replacement, and stale-tick replacement regressions.
- Hardened CombatComponent with attack-generation identity and grounded-completion-before-overlap ordering; independent re-audit reports PASS.
- Final sign-off passes configuration, Godot import, all five smoke suites, main-scene startup, diagnostic/debug scans, and `git diff --check`.

## Quarter-height back-kick session

- Captured the red baseline: back kick reached 51.00 px instead of the requested 12.75 px.
- Added data-driven `jump_height_scale = 0.25` to back kick and discrete-apex takeoff solving to JumpComponent.
- Focused special-move regression now passes the exact 12.75 px apex while retaining descent hold, air control, landing completion, and reversal checks.
- Independent audit reports PASS; final configuration, import, five-suite, main-scene, diagnostics, and diff validation all pass.

## Directional head-attack correction session

- Reviewed and preserved the clarified directional reference as `head-attack-directional.png`.
- Captured the red baseline: the animation had only two entries instead of pose 1 → pose 2 → pose 1.
- Reused the first texture as SpriteFrames pose 3, scheduled it at recovery frame 10, and corrected source-art orientation to rightward.
- Focused regressions now pass complete left/right pose timing, mirroring, exact directional travel, and final facing.
- Independent audit additionally verified bidirectional physical hits/knockback and reports PASS.
- Final configuration, Godot import, all five smoke suites, main-scene startup, diagnostics, and `git diff --check` pass.
- Captured the expected red baseline: the special-moves smoke test reports missing `elbow_attack_data`.
- Completed an independent architecture/test audit and tightened command windows, landing classification, movement-before-hit order, cancellation-safe reversal, and frame-driven pose contracts.
- Implemented the generalized attack metadata, cancellation-aware CombatComponent finish payload, rear hit direction, movement API, chord/double-tap recognition, and reordered player physics orchestration.
- Generated and imported 14 exact, feet-aligned special-move frames; added four SpriteFrames animations and four AttackData resources.
- The new special-moves suite passes its initial behavior/physical overlap checks; legacy smoke waits are being updated for the deliberate chord window.
- Updated all legacy smoke expectations for the three-frame grounded chord-resolution delay; all five suites pass.
- Added full pose-schedule, command-boundary, facing/cancellation, movement-distance, jump-trace, and front-vs-rear physical regressions.
- Fixed final-active moving hit detection with a current-transform direct-space shape query; the strengthened special-moves suite and all legacy suites pass.
- Addressed follow-up audit findings: airborne K+L now resolves to jump kick, activation preserves air control, recovery completion has no locomotion hitch, and extraction is byte-idempotent.
- Re-ran all five diagnostic-aware suites after the fixes; all pass.
- Hardened input isolation, semantic direction edges, facing latching, frame-zero head movement, and re-entrant combat lifecycle/payload behavior from two additional independent audits.
- Final completion audit reports PASS.
- Final sign-off: two byte-identical extraction runs, idempotent configuration, Godot import, all five smoke suites, main-scene startup, diagnostic scan, debug-tag scan, and `git diff --check` all pass.

## Aerial kick landing-hold session

- Reviewed the two new single-pose references with native image input; they select the extended kick pose (index 3) for jump kick and back kick.
- Scoped completion to retaining attack state, ACTIVE hitbox, and pose until landing, with back-kick reversal delayed to that natural completion.
- Started Phase 1 regression work.

## Williams enemy session

- Loaded godot-master composition, state-machine, CharacterBody2D, combat, physics-query, and testing references.
- Re-read all common components, the player orchestrator, attack resources, the prototype alley, the smoke runner, and the Billy extraction manifest.
- Inspected `williams.png` natively and recorded its matte and row layout.
- Replaced the completed head-attack task plan with the Step 6 Williams plan.
- Captured the red baseline: `WILLIAMS_SMOKE_TEST_FAIL: Williams scene is missing`; registered the suite in `tools/run_smoke_tests.py`.
- Factored feet-pivot extraction into `tools/lib/frame_extraction.sh`; Billy regeneration stays byte-identical.
- Added `tools/extract_williams_frames.sh` and generated 19 transparent Williams frames; contact sheet and numeric pivot audit both pass.
- Generated `williams_sprite_frames.tres` (seven animations) and gave Billy's death animation the two fall poses before the prone pose.
- Added shared `PoseSchedule`, `HitReactionComponent`, hit-reaction FighterStats fields, `AttackData.knocks_down`, and hurtbox invulnerability.
- Added `EnemyStateMachine`, `EnemyAIComponent`, `EnemyVisuals`, the `Williams` orchestrator/scene/stats, and `williams_punch.tres`.
- Wired Billy's hurtbox to hitstun/knockdown/death through the shared reaction component; player visuals now schedule hurt/knockdown/death poses.
- Slice 1 is green: `WILLIAMS_SMOKE_TEST_PASS` for standalone load, animation contract, collision layers, pivots, and idle-without-target.
- Wrote the fighting-loop slices: approach/attack into Billy, Billy's hit chain into Williams (hitstun ×2, knockdown, invulnerability, death, defeat), forced retreat, depth alignment, and airborne knockdown.
- Fixed the one-frame reaction presentation lag, the freed-lambda diagnostic, and the reaction-delay latch; the Williams suite passes all six slices.
- Placed one Williams in the prototype alley; Step 4 and Steps 4–5 suites now assert his presence and isolate Billy afterward.
- Sign-off run: editor import, all six smoke suites, 120-frame main-scene startup, and `git diff --check` pass with zero diagnostics. Independent audit launched.
- Self-audit hardening: cooldown now restarts on punch completion and death without a hit starts the death reaction; both have regressions in the Williams suite, which passes seven slices.
- Independent audit hosted in Herdr tab `williams-audit` returned BLOCK (one medium, nine lows) after eight runtime probes; report saved in the session scratchpad.
- Fixed all ten audit findings with six new regression slices (depth from overlap, lazy/dead target, chain reset zero, interrupted-attack states, recovery-tick locomotion, wall-ended retreat) and two tightened assertions; the Williams suite passes thirteen slices.
- Final sign-off rerun: editor import, all six suites, 240-frame main scene, debug scan, and `git diff --check`.

## Prototype level encounter session

- Saved the Herdr-pane preference for forked sessions to memory.
- Loaded godot-master camera, wave-loop, and scene-management references; measured the New York composite and chose the 1232×216 street slice.
- Replaced the completed Williams task plan with the Step 7 plan.
- Captured the red baseline: parse errors for `EncounterController`, `PrototypeAlley.PLAYING`, and the HUD surface; registered `tools/smoke_test_encounter.gd`.
- Added `tools/extract_stage_section.sh`, `BeltScrollCamera`, `EncounterController`, the `Hud` scene, `HealthComponent.maximum_health()`, Billy's screen-edge mask, and rebuilt the prototype alley scene and orchestrator.
- Slice 1 (level contract) green; Step 4 suite updated for the new strip (left 7, right 377, top 160, bottom 216) and the encounter disabled in both level suites.
- Camera, encounter flow, HUD, and defeat/restart slices green after disabling the encounter inside the camera slice.
- Added the live-entry slice (enemy walks through the screen edge) and the live-fight/reload soak; fixed the freed-capture wait and shortened the fight so the suite runs in about 12 s.
- Full run: all seven suites pass, 240-frame main scene clean, editor import clean, `git diff --check` clean. Independent audit launched in Herdr pane `wR:p5` (agent `encounter-audit`).
- Independent audit returned PASS with three mediums and eight lows after five runtime probes; report saved in the session scratchpad.
- Fixed all eleven findings: paced, forward-only, target-safe camera locking and unlock catch-up; instance-id enemy counting; no spawns after defeat; disabled encounters clear the exit; enemy contract validated at ready; notes and test helpers corrected. Four new slices plus tightened existing ones bring the encounter suite to eleven slices.
- The first paced-pan attempt let a screen-edge wall bulldoze a teleported Billy; the cap now applies only while the target is in view, with a snap regression.
- Final sign-off rerun: all seven suites, 240-frame main scene, editor import, and `git diff --check` pass with zero diagnostics.


## Ladder climbing session

- Saved the user's ladder location and climb references under `documents/double-dragon/references/`.
- Located the four climb poses on the Billy sheet and measured the SCOOP ladder in the stage slice.
- Replaced the task plan with the ladder plan; captured the red baseline (`Ladder` type missing) and registered `tools/smoke_test_ladder.gd`.
- Extracted the climb frames through the shared feet-pivot library (existing frames byte-identical) and added the `climb` animation.
- Added `Ladder`, `ClimbComponent`, `FighterStats` climb fields, the CLIMB state, climb presentation, player wiring, and the level ladder.
- Fixed a misplaced `.tres` block, a test lambda arity, grounded-offset expectations, and the grab-zone tolerance; all eight ladder slices pass.
- Full sign-off: all eight suites, 240-frame main scene, editor import, extraction idempotency, and `git diff --check` clean; audit launched in the Herdr pane.
- Measured the ladder art: recentred the ladder from x 525 to 522 and clamped the climb to 96 px so Billy's sprite stays on screen; the suite now asserts both.
- Independent audit (four runtime probes inside the real level) returned BLOCK on one high and four mediums plus four lows, and found a chain-reset defect outside the ladder scope.
- Fixed all nine ladder findings and the chain-reset defect; the ladder suite was rewritten to run every slice inside the real level and now has thirteen slices, and the Williams suite gained a chain-decay regression.
- Final sign-off rerun: all eight suites, editor import, 240-frame main scene, and `git diff --check` pass with zero diagnostics.


## Ladder climb pose correction

- The shipped climb used the sheet's side-view walk repeat at y≈515: Billy climbed facing sideways in a fighting stance.
- Matched the user's reference against the sheet (`compare -subimage-search`): the climb cycle is five rear poses in band y 174–235 at x 16, 46, 78, 110, 139.
- Added `extract_anchored_frame` to the shared library: per-pose foot centring would swing the body with the lifted leg, so the strip keeps its own floor row and hangs from the head's centroid.
- Replaced the reference image, re-extracted five frames, added `climb_04` to the SpriteFrames, and reimported (Billy's stats resource checked and unchanged).
- The ladder suite now reads the pose count from the artwork and asserts the shared head pivot; the Step 4 pivot audit exempts `climb` with the reason recorded.
- Verified by rendering the real level: eight windowed captures of Billy climbing to the 96 px clamp, the probe script removed afterwards.
- All eight suites pass; editor import and `git diff --check` clean.

## SCOOP ledge: climbing onto the platform

- Measured the destination in the sheet: the cornice's cap line is row 288 and its stone starts at 289 (world y 25), the corbel run spans x 493–810, and the building's second ladder is at x 777.5 — correcting a findings note that had put it near x 609.
- Re-cropped the stage slice from `1232x216+0+264` to `1232x272+0+208` and drew it at y −56, which gives the camera 56 px of headroom without moving a single ground coordinate. Row 208 is the highest crop with no hole across the span the raised view can cover.
- Added `ClimbPlatform` (a height plus the span its surface covers) and `Ladder.platform` / `top_height()`, so two ladders onto one ledge cannot disagree about where the top is.
- Extended `ClimbComponent` with the ledge: the top rung steps onto it, down over a serving ladder steps back onto the rungs, `release()` drops from either, and an elevated actor now drops collision layer 2 as well as its hurtbox.
- Unified the player's elevated tick. The top step ends the climb without ending the elevation, and the old separate branch let the fall-through reach the jump's visual reset, dropping Billy to the ground for one tick.
- Gave the belt camera a rising band (1:1 with the target's elevation, stopped by `limit_top`) and took the band's size from the project's design viewport: a headless run reports a square 384×384 dummy, so every framing rule and every test of one was measuring a screen that does not exist.
- Gated the encounter trigger on a player standing on the ground plane, so crossing x 640 along the ledge no longer arms a fight that would only drop Billy off the cornice.
- Placed `Ledges/ScoopLedge` (surface y 25, walk span 501–831) and `Ladders/ScoopRightLadder` at x 778 in the prototype alley.
- Grew the ladder suite to nineteen slices: the ledge's geometry read out of the stage texture, the top step, walking and its end stops, the crossing to the far ladder and down to the street, the camera's rise and return, a climb-only ladder still clamping, and the encounter's new gate.
- Raised the runner's per-suite budget to a named 120 s: headless Godot paces physics to real time and the suite now climbs 135 px a dozen times (about 33 s).
- Verified in the real renderer: eleven windowed captures of the whole loop — up the left ladder, along the cornice, down the right one — with the probe removed afterwards.
- All eight suites pass; extraction idempotent, editor import clean with Billy's stats resource unchanged, and `git diff --check` clean.

## Hit-confirmed combo chains (plan Section 9, item 1)

- Read both combo references out of the sheet rather than by eye: `three-hit-punch.png` sits at x 404, y 264 and `three-hit-kick.png` at x 107, y 344, and the punch band's third pose group hashes identically to its first — so the chain's second punch is the sheet's other-arm cross and the finisher is the four-pose rising uppercut.
- Extracted nine new feet-pivoted frames (`punch_cross` 3, `uppercut` 4, `turn_kick` 5) from their own measured bounding boxes; all 44 existing frames stayed byte-identical and the extraction is idempotent.
- Added `AttackChainComponent`: it owns the step and the window, advances only when its own step ran to the end and connected, and resets on a whiff, an interruption, a different move, or a lapsed window. `CombatComponent` still knows nothing about chains.
- Wired the player's attack and kick buffers to the chains, with `FighterStats.chain_window_frames` (24) as the tuning knob and a failed start breaking the chain rather than leaving it waiting.
- Both finishers knock down, which gives the combo its payoff and matches the arcade original.
- Rendering the chains in the real level found the defect the headless slices had missed: the openers knock the target back about 10 px per punch and 16 px per kick, so both finishers whiffed. Every step after an opener now lunges forward over its startup, and the reach slice presses only once the target has stopped sliding — the furthest the next step ever has to reach.
- Fixed the suite's own blind spot: a dummy hurtbox parked on Billy satisfied "the hit landed" even for a whiffed finisher, so reach is now read from the target's health.
- Updated two Williams slices that punch three times in a row: the third punch would now be the uppercut, so each press there is an explicit fresh opener and the target's consecutive-hit rules stay covered.
- Verified in the real renderer: both chains land all three steps and leave Williams knocked down, captured frame by frame; the probe was removed afterwards.
- All nine suites pass; extraction idempotent, editor import clean with Billy's stats resource unchanged, 240-frame main scene and `git diff --check` clean.

## Stage music

- Fetched the arcade soundtrack through the browser: twelve tracks resolved one page at a time to their direct URLs, then downloaded to `assets/audio/bgm/` under track-numbered snake_case names. All twelve verified as real MPEG layer III with durations matching the album listing.
- Imported them with looping on for the six tracks that underscore open-ended play and off for the six fixed-length cues, because Godot's own default of `loop=false` would leave a stage silent three minutes in.
- Added `MusicPlayer`: one track, asserted to exist and to loop, started with the level. Level-owned rather than an autoload — the project has no autoloads, and one stage cannot justify inventing the pattern.
- Gave the prototype alley its stage theme, `02_slums.mp3`, at -6 dB, wired like every other collaborator the level validates on ready.
- Wrote `tools/smoke_test_music.gd` (5 slices): the album is installed and imports, the loop table holds, `loops()` tells a loop from a cue, the stage plays its own theme, and the track actually comes back round when seeked to its end.
- Adding music turned five existing suites red with leaked-stream diagnostics that had nothing to do with their subject. Diagnosed it to the audio server's mixing pass rather than frames, and gave the suites `tools/lib/audio_settle.gd` to wait on it — after measuring that a frame-count wait was the flaky thing that caused it.
- Removed an `_exit_tree` override once measurement showed it did not change the exit behaviour it was written for. Recorded the remaining intermittent exit diagnostic honestly in `findings.md` rather than claiming a clean main-scene run.
- Mutation-checked both halves: dropping `play()` fails "must start its track with the level", and importing the stage track without its loop flag fails "02_slums.mp3 must loop, and does not".
- All ten suites pass, stable across three consecutive full runs; verified on a real audio device (CoreAudio, −17.4 dB on the master bus); `git diff --check` clean and no probe scripts left behind.
