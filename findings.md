# Findings

## Existing project

- Godot project targets 4.7 and the GL Compatibility renderer.
- The project currently contains only `project.godot`, `icon.svg`, instructions, and documentation.
- Godot CLI is available at `/Applications/Godot.app/Contents/MacOS/Godot`.
- The external asset folder contains 13 valid PNG sheets.

## Asset observations

- Character sheets are irregularly arranged reference sheets rather than uniform grids.
- Character sheets have opaque matte backgrounds; `billy-lee.png` uses RGB `(128, 164, 128)` / `#80A480`.
- Frames must be cropped individually and aligned around a consistent feet pivot.
- `new-york-20xx.png` is a long composite stage sheet and is not part of the player-scene implementation.
- The top Billy sheet area contains clean side-view walk and punch sequences suitable for the initial player scene.
- Later sheet rows contain hit reactions, falls, prone poses, and recovery frames; the first implementation can use representative subsets without processing every throw variation.
- Sprites are separated by substantial matte space, so fixed crop rectangles with transparent padding are practical and preserve stable pivots.
- The first punch sequence occupies approximately source `y=276..338`; its first three poses are isolated around `x=16`, `x=54`, and `x=108`.
- Initial hurt/fall candidates are in the `y=775..980` range. Fixed 80×80 output canvases with south-center gravity will keep standing and grounded poses aligned consistently.
- First contact-sheet validation showed adjacent-pose fragments in several crops. The crop widths need to stop before neighboring sprites; the matte removal and bottom-center alignment themselves are correct.

## Architecture

- A belt-scroller uses CharacterBody2D `x/y` ground movement, with any later jump height represented separately.
- `AnimatedSprite2D` is sufficient for initial frame-based presentation; AnimationTree would add unnecessary complexity.
- State, input, movement, health, and combat ownership should be separated into typed components and coordinated by the player root.
- Godot's `InputMap` runtime mutations did not persist when the configuration script exited; assigning `input/<action>` dictionaries through `ProjectSettings` persisted the actions correctly.
- Godot 4.7 imported the generated textures, SpriteFrames resource, typed components, and player scene without parse or load errors.
- Final contact-sheet review confirms the selected idle, walk, punch, hurt, knockdown, and death frames have transparent backgrounds, consistent 80×80 canvases, and usable bottom-center alignment.
- The smoke-test failure was a frame-order issue: `SceneTree.physics_frame` resumes before node physics callbacks for that boundary. Synthetic input must remain pressed across a second boundary before assertions.

## Directional walking bug

- The regression loop fails deterministically with `Horizontal movement must use walk_side` because `PlayerVisuals._animation_for_state()` maps every MOVE direction to one `walk` clip.
- The existing `walk` frames are the rear-facing sequence reported by the user and should become `walk_up`.
- The sheet has a front-facing four-frame row at approximately `y=88`, suitable for `walk_down`.
- The sheet has a separate side-facing four-frame repeat row at approximately `y=510`, suitable for `walk_side` and horizontal flipping.
- Direction selection should use the dominant input axis; vertical wins ties so direct up/down and 45-degree diagonals are visually stable.
- The first side-row crop included the sheet's `REPEAT` annotation and adjacent frame fragments. Tightening the side crops to `y=512..581` and narrower x ranges produced four clean frames.
- Final directional contact sheet: row 1 is side/front-visible, row 2 is the requested rear-facing/up sequence, and row 3 is front-facing/down.
- Follow-up requirement: horizontal movement should use the exact `walk_down` clip, not a separate side clip. `walk_side` is therefore unnecessary and has been removed from generated assets and SpriteFrames.

## Steps 4–5 audit

- Existing ground movement already uses semantic actions, normalized input, and separate horizontal/depth speeds.
- Existing `AttackData` has most planned values, but no attack resource instance is wired to the player.
- Existing `CombatComponent` tracks only a single total duration; it does not expose phases, toggle/query the hitbox, resolve damage, or deduplicate targets.
- Existing attack buffering is an indefinite boolean while attacks are locked out, rather than the planned finite 6–8 physics-frame window.
- The current project has no Y-sorted actor container, movement boundaries, or independent jump-height simulation.
- Godot architecture review recommends a dedicated `JumpComponent`: it owns height/velocity, moves only `Visuals`, and leaves the actor root as the feet/depth-sort coordinate.
- Level-owned `StaticBody2D` boundaries should remain outside the Y-sorted `Actors` container; existing player collision masks already scan world layer 1.
- `AttackData` must be the sole timing/geometry source. The 18-tick contract is startup frames 0–4, active 5–7, recovery 8–17, finished at elapsed frame 18.
- Facing must be shared gameplay state: a punch snapshots facing, mirrors hitbox offset without scaling collision nodes, and uses that snapshot for knockback.
- A finite eight-frame single-slot attack buffer should decay during lockout and be consumed immediately if recovery finishes while still valid.
- Detailed behavior can be tested deterministically through direct physics-tick methods; retain a real physics-backed overlap test for Area2D integration and the standalone player smoke test for F6 safety.
- Keep `AnimatedSprite2D` presentation independent from combat authority; animation completion and playback speed must not control damage timing.
- Independent completion audit found a physics-flush hazard: lethal damage delivered from `Area2D.area_entered` can synchronously trigger player death and attack cancellation, which currently mutates hitbox physics state during query flushing.
- Cancellation must make logical combat state inactive immediately but defer physical `monitoring`/shape changes when invoked from a physics callback; overlap handlers already reject hits outside the logical ACTIVE phase.
- The extraction script bottom-aligns frames but horizontally centers the entire trimmed pose. To satisfy the feet-origin requirement, generated poses should instead align the midpoint of opaque pixels in a bottom foot band to canvas x=40.
- A regression must cover lethal overlap against a currently attacking victim because normal nonlethal overlap and out-of-callback cancellation do not expose the flush hazard.
- Physics-safe cancellation is now verified by a lethal real-`Area2D` overlap: logical phase/hit acceptance stops immediately, while collision monitoring/shape disabling is deferred during the physics frame. No flush diagnostic is emitted.
- Initial ImageMagick bottom-band audits using `%@` after crop/repage did not retain useful canvas x offsets (reported trimmed content at x=0), so the alignment script should calculate feet midpoint before final canvas placement rather than infer it from already repaged output.
- ImageMagick `%g`/`%X` retains the trim page offset correctly (for example, current `punch_01` lower band begins at canvas x=12 while idle begins at x=30). This provides a reproducible way to place each trimmed pose so its bottom contact midpoint lands at canvas x=40.
- Visual source audit found that `punch_01`'s crop extends into the next pose at x≈107, producing the isolated floor pixel seen in the generated contact sheet; narrowing its crop avoids false pivot detection.
- `hurt_01` starts at x=52 while the previous falling pose extends through roughly x=61, so it contains a neighboring boot fragment. Starting the second hurt/knockdown pose near x=66 isolates it cleanly.
- For standing/moving poses, a narrow bottom-contact band identifies the supporting boot more accurately than centering the full pose. For prone/falling poses, the same ground-contact midpoint provides a deterministic floor anchor even when both feet are not planted.
- Regenerated frames now place every four-row floor-contact midpoint at canvas x≈40 (integer rounding yields 39.5–40.5) and the contact at y=80. The final contact sheet shows the stray punch pixel and neighboring hurt fragment are removed.
- Visual review of the regenerated set confirms consistent grounded contacts without clipping; pose/body displacement now occurs around the support point rather than around each crop's arbitrary bounding-box center.
- Re-audit caught edge clipping that the contact sheet did not make obvious: `punch_01` trims to 46 px wide but its lowest support pixels are near x=2–7, so aligning only that planted foot to x=40 places the final source column at canvas x=80. Anatomical **feet midpoint** must consider both boots in a taller lower-leg band, which also avoids clipping.
- Source crop bounds also need one-time corrections: include x=108 for `walk_down_03`, include the full first falling pose through x=62, and keep isolated neighboring poses out.
- Testing foot-band heights on the isolated 46×59 punch pose showed that four rows see only one planted boot (midpoint x=5), while eight rows capture both boots (midpoint x=12). Eight-row alignment fits the complete pose at canvas x=28..73 with no clipping.
- Simulating all corrected crop rectangles with an eight-row lower-leg/feet band produced floor midpoints at x=39.5–40 and left/right extents strictly inside the 80×80 canvas for every frame.
- Final regenerated contact sheet after eight-row alignment and crop-bound corrections shows complete fists/boots, no neighboring annotation pixels, and visible margins at both canvas edges.
- The apparently detached lower boot in the first falling pose is part of that source pose (visible in the isolated sheet row), not a neighboring-frame artifact.
- Added `tools/run_smoke_tests.py` because Godot may return exit code 0 after script/runtime errors; the runner also rejects ERROR/WARNING diagnostics and timeouts.
- Final independent audit reports PASS for every explicit Step 4 and Step 5 requirement with no remaining high/medium defects.

## Jump animation correction

- User reference shows a two-pose jump: a stretched takeoff/ascent pose followed by a compact airborne tuck/rotation pose. The current implementation keeps idle/walk presentation during the whole physics arc, so it cannot match.
- The deferred basic kick reference shows two poses: chamber and high side-kick extension.
- The deferred three-hit punch reference shows advancing punches followed by a rising uppercut/finisher; it must be hit-confirmed rather than advancing on whiff.
- The deferred three-hit kick reference shows an advancing kick sequence ending in a turning/back-kick finisher; it likewise depends on enemy hit confirmation.
- The clipboard references are opaque, resampled screenshots with dominant background `#6F9A77`, not exact source-sheet pixel crops using the original matte, so direct exact-color/template matching is unsuitable.
- Full-sheet visual inspection located the requested jump pair in `billy-lee.png` around source x=10–92, y=430–505: first the stretched rising pose, then the compact airborne tuck. The adjacent third pose is not part of the user's two-frame reference.
- Candidate crop inspection confirms both requested poses are cleanly isolated from neighboring rows using approximate rectangles `38x75+10+430` and `42x60+50+445`, with transparent trimming providing final bounds.
- The generated transparent contact sheet matches the user's reference: stretched rising pose first, compact tuck/descending pose second, with no neighboring pixels or clipping.
- Deterministic presentation is preferable to free-running animation: nonnegative jump velocity selects frame 0 and negative jump velocity selects frame 1, while `JumpComponent` remains the physics authority.
- All four clipboard references are now persisted under `documents/double-dragon/references/`; the plan links the deferred basic kick and hit-confirmed combo requirements to durable files.

## Diagonal and retained facing bug

- The desired neutral screenshot keeps Billy's previous rear/side locomotion view; the current screenshot resets to the generic front-facing `idle` clip.
- Up-left/down-left contain a negative horizontal component and therefore must flip horizontally even when the chosen animation is `walk_up`.
- Neutral input needs both pieces of persistent presentation state: last horizontal facing and last locomotion clip/view.
- Root cause confirmed: `PlayerVisuals` explicitly suppressed horizontal flipping whenever the walk was vertical-dominant, even if x was negative, and all neutral IDLE states unconditionally selected `idle`.
- The fix updates facing from every nonzero x component, remembers only MOVE-selected locomotion clips, and pauses that clip when neutral. Jump/punch/hurt/death therefore cannot overwrite retained locomotion direction.
- Resuming the same locomotion clip must explicitly call `play()` when it is currently paused; checking animation-name equality alone would leave Billy frozen while moving again.
- Final behavior: every negative horizontal component flips left, pure vertical movement preserves the last horizontal facing, and neutral state pauses the remembered up/down locomotion view on its current frame.

## Double-height jump and basic kick

- The supplied kick reference is the same two-pose chamber/high-side-kick sequence already stored as `documents/double-dragon/references/basic-kick.png`.
- Current jump parameters (`180 px/s` takeoff, `600 px/s²` gravity) produce an approximately 25–27 px discrete apex; doubling height requires approximately `sqrt(2)` times takeoff speed if gravity and overall feel remain otherwise unchanged.
- L is currently assigned to the reserved `grab` action, so a semantic `kick` action must claim L and `grab` must no longer share it.
- Exact red baselines: current discrete apex is `25.50 px`; player smoke reports `Missing semantic kick action`.
- Combat and visuals confirm the predicted seams: `CombatComponent` reads one exported `attack_data` everywhere, and ATTACK presentation always returns `punch`.
- Source-sheet inspection located the supplied kick pair around x=12–92, y=350–422. Candidate rectangles are approximately `34x72+12+350` for chamber and `45x72+47+350` for extension.
- `configure_project.gd` also resets the main scene to the standalone player and binds L to grab; it must be updated alongside `project.godot` so regeneration remains idempotent.
- A `252.4 px/s` takeoff impulse with unchanged `600 px/s²` gravity yields the desired discrete 60 Hz apex of approximately 51 px, exactly double the measured 25.50 px baseline.
- The generated kick frames visually match the supplied chamber and high-extension poses, fit cleanly inside 80×80 canvases, and retain the common feet anchor.
- Combat can remain a deep reusable module by keeping `attack_data` as the default punch and latching an optional `current_attack_data` for kick; phase, geometry, damage, and deduplication then work unchanged for either attack.
- Project regeneration now preserves the prototype alley main scene, binds L only to `kick`, and leaves `grab` present but unbound.
- Independent audit found the grounded request correct but exposed three input-interaction defects: ground punch/kick can start invisibly while jump visuals override them, jump requests can latch indefinitely through an attack, and separate punch/kick buffers give fixed punch priority rather than latest-input priority.
- Correct behavior for this non-combo phase: ground attacks cannot start while airborne; jump uses a finite buffer; queuing punch clears kick and queuing kick clears punch so the latest attack request owns the single effective slot.
- Focused edge-case regressions now pass: early K during kick expires instead of auto-jumping, airborne L never starts a hidden ground hitbox, and the most recently queued J/L attack replaces the older buffer.
- Final-frame pre-landing jump input is preserved by advancing jump physics/landing before testing grounded jump eligibility, then synchronizing the ground coordinate after movement.
- `_unhandled_input` capture flags prevent the same real events from being replayed in fixed polling order; polling remains as the synthetic/controller fallback when no event was captured.
- Final independent audit reports PASS: exact apex, kick animation/timing/damage, bindings, airborne safety, finite pre-landing buffer, and real latest-event attack priority all have evidence with no high/medium blockers.
- Kick presentation is phase-aligned rather than free-running: chamber frame during six startup ticks, high-extension frame from the first active tick onward.
- Existing punch tests continue to exercise the default `attack_data`; kick tests exercise `current_attack_data`, proving the generalized component did not duplicate phase/hit logic.
- Physical overlap now verifies one punch plus one kick produce exactly two hit events and damage totals; the input suite verifies kick-buffer expiry and punch-to-kick late-recovery chaining.
- The completed punch uses `billy_punch.tres` as the sole timing and hitbox-geometry source; no stale total-duration property, Timer, or gameplay `await` remains.
- Physical Area2D integration succeeds in headless physics: the active window detects an overlapping enemy-layer hurtbox once and reduces health by exactly 10.
- The main scene can now be the bounded prototype-alley scaffold while `player.tscn` remains independently runnable and covered by its original smoke test.
