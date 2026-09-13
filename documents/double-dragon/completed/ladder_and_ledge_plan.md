# Completed Task Plan: Ladder Climbing and the SCOOP Ledge

## Goal

Let Billy climb the ladder on the SCOOP MOTO building (reference `documents/double-dragon/references/ladder-location.png`) with the five-frame rear-view climb cycle in `ladder-climb.png` (a repeating cycle). Pressing up at the ladder's base grabs it; up and down climb with the cycle driven by distance; the top rung clamps the climb; climbing down to the base and pressing down or sideways steps off. The body stays on the ground plane while the visuals rise, exactly like the jump.

## Agreed test seams

- `Ladder` (Area2D, layer 9): `climb_height`, base at its origin; placed in the prototype alley at the left ladder.
- `ClimbComponent` on the player: `is_climbing`, `climb_height`, `pose_index()`, `try_grab()`, `physics_tick(vertical_input, delta)`, signals `climb_started` / `climb_finished`; visuals rise by `climb_height`; hurtbox invulnerable while climbing.
- `Player`: enters `PlayerStateMachine.CLIMB` from up at the base; ignores attack, kick, and jump buffers while climbing; returns to locomotion on dismount; presents the `climb` animation with the distance-driven pose.
- Billy `SpriteFrames`: `climb` has five 80×80 frames from the sheet's rear climb strip, hung from the head's column rather than the feet.

## Phases

- [complete] Phase 1 — Red baseline `tools/smoke_test_ladder.gd`, registered in the runner.
- [complete] Phase 2 — Extract the five climb frames through the anchored extraction; add the `climb` animation.
- [complete] Phase 3 — `Ladder` scene, `ClimbComponent`, `FighterStats` climb fields, player state/visual wiring.
- [complete] Phase 4 — Place the ladder in the level; grab / climb / clamp / dismount / invulnerable / buffered-input slices green.
- [complete] Phase 5 — All suites, editor import, main scene, `git diff --check`; plan, handoff, findings, progress; independent audit in a Herdr pane; GenUI summary.

## Goal (ledge)

Billy climbs the SCOOP building's ladder and stands on the stone cornice above it, walks along it, and climbs down the building's second ladder. The ledge is a height and a span, not a second floor: the body keeps the one ground plane and only the visuals rise, exactly as the jump and the climb already do.

## Agreed test seams (ledge)

- `ClimbPlatform`: `height`, `walkable_width`, `left_x()` / `right_x()` / `covers_x()` / `hold_x()`; placed on the cornice the stage art draws.
- `Ladder.platform` and `Ladder.top_height()`: a ladder that leads to a ledge climbs to the ledge's height, and a ladder without one still clamps at `climb_height`.
- `ClimbComponent`: `is_on_platform`, `platform`, `platform_tick()`, `hold_on_platform()`, `is_elevated()`, `elevation()`, signals `platform_entered` / `platform_exited`; the top rung steps onto the ledge, down over a serving ladder steps back onto its rungs, `release()` drops from either.
- `Player`: walks the ledge with x only, presents IDLE/MOVE rather than CLIMB up there, keeps the ladder's dropped-input rules, and answers `is_elevated()` / `visual_elevation()`.
- `BeltScrollCamera`: the band rises with the target's elevation and `limit_top` stops it at the top of the stage art.
- `EncounterController`: the trigger waits for a player on the ground plane.

## Phases (ledge)

- [complete] Phase 6 — Measure the cornice and the second ladder in the sheet; re-crop the stage slice with headroom and draw it at y −56.
- [complete] Phase 7 — `ClimbPlatform`, `Ladder.platform`, `ClimbComponent` ledge states, `Player` ledge tick.
- [complete] Phase 8 — Rising camera band, encounter elevation gate, level placement of the ledge and the second ladder.
- [complete] Phase 9 — Suite slices for the ledge; all eight suites, editor import, windowed capture, docs.

## Scope Decisions

- The ledge is the SCOOP building's cornice, surface at world y 25, spanning the corbel run x 493–838 with the walk inset to 501–831. Both of the building's ladders lead to it (x 521.5 and 777.5 by the rails the art draws), which is what makes the ledge a crossing rather than a dead end.
- The stage slice grew from `1232x216+0+264` to `1232x272+0+208` and is drawn at y −56, so no ground coordinate moved and the camera has somewhere to rise. Sheet row 208 is the highest crop with no hole in the span the raised view can cover; the garage at x 0–255 only starts at row 224.
- The camera band rises 1:1 with Billy's climb and stops at `limit_top`, so his feet hold a constant screen row until the art runs out and he then rises in frame. A jump deliberately does not move the band.
- On the ledge Billy may only walk: attacks, kicks, and jumps stay blocked as they are on a rung, and he stays invulnerable because he is still off the ground plane. His body also drops collision layer 2 while elevated, so he passes over anyone standing under the cornice.
- The encounter's trigger now waits for a player on the ground plane, so crossing x 640 along the ledge does not arm a fight that would only drop him off it.
- Grabbing uses an immediate `intersect_point` query against ladder areas on layer 9 so there is no one-tick sensor lag; enemies never mask that layer.
- While climbing Billy is off the ground plane, so his hurtbox is invulnerable and his own attacks are blocked; enemies keep targeting the base.
- Climb speed and pose spacing live in `FighterStats` (`climb_speed`, `climb_pose_pixels`), keeping the data resources authoritative.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| Red baseline: `Could not find type "Ladder"` | 0 | Expected red; resolved by the implementation. |
| `Condition "!f.has("texture")" is true` loading Billy's SpriteFrames | 1 | The climb block had been inserted inside the death animation's frame list; moved it between `back_kick` and `death`. |
| `Method expected 0 argument(s), but called with 1` on `climb_started` | 1 | The test lambda now accepts the ladder argument. |
| `The visuals must rise by the climbed height` | 1 | The Visuals node rests at y −40; the test now compares against the grounded offset. |
| `Landing on the base with up held must grab the ladder` | 1 | Air movement carried Billy 2 px above the base; the grab zone now reaches 8 px above the base. |
| Step 4 pivot audit: `climb frame 3 feet midpoint is 38.5 instead of 40` | 1 | The library's `-trim` read an opaque corner as background; a transparent border now pads the band. Existing frames byte-identical. |
| Same failure after the fix | 2 | Godot's import cache still held the old PNG; the editor import refreshed it. |
| Ladder placed at x 525 by eye | 1 | Measuring the art put the rails at x 513.5 and 529.5, so the ladder moved to 522 and the suite now asserts the measured centre. |
| `already a for loop iterator named "node"` / `Identifier "base" not declared` | 1 | Renamed the inner loop variable and hoisted the `base` declaration above its use. |
| `Grabbing must snap Billy onto the ladder's base, got (522.0, 160.0747)` | 1 | The body rests against the strip's top boundary at Godot's physics safe margin; the suite allows that sub-pixel offset. |
| `Freed-ladder setup: Billy must be on the spare ladder` | 1 | The spare ladder at x 700 tripped the encounter, which now closes ladders; the suite disables the encounter in every climb slice. |
| Wrong strip: Billy climbed facing sideways in a fighting stance | 1 | The poses came from the side-view walk repeat at y≈515. The real climb cycle is the five rear poses at band y 174–235, found by matching the user's reference against the sheet. |
| `climb frame 0 feet midpoint is 41.5 instead of 40` | 1 | The climb poses deliberately no longer pivot on their feet; the Step 4 audit exempts `climb` and the ladder suite asserts the head pivot instead. |
| `The visuals must stay raised by the ledge's height` | 1 | The top step ends the climb without ending the elevation, so the tick fell through to the jump's visual reset. Both the rung and the ledge are now ticked inside one `_process_elevated`. |
| `The band must start on the ground plane, got 136` | 1 | A headless run reports a square 384×384 dummy viewport, so the camera's vertical clamp was measuring a screen that does not exist. The band's size now comes from the project's design viewport. |
| `Walking the ledge must not take Billy off it` | 1 | The slice pressed down while Billy still stood over the ladder he came up, which is the intended way back onto the rungs. The depth check moved clear of the ladder. |
| `Encounter setup: reaching the lock x must start the fight` | 1 | True by design now: the trigger waits for the ground plane. That slice drives the level's handler from `encounter_started` instead, and the new gate has its own slice. |
| Ladder suite `timed out after 30 seconds` | 1 | Headless Godot paces physics to real time, and the suite climbs 135 px several times. The runner's budget is now a named 120 s constant, and the grab-depth slice dropped its redundant middle depth. |

## Completion Evidence

| Requirement | Evidence |
|---|---|
| Climb frames | Five 80×80 frames from the sheet's rear climb strip (band y 174–235), every pose on the canvas floor and hung from the head's column so the cycle cannot swing sideways; existing Billy frames byte-identical after regeneration; `climb` animation loops with five poses. |
| Level ladder | `Ladders/ScoopLeftLadder` at (522, 160) on layer 9, passive, 96 px climb; the suite finds it through the `ladders` group, checks it is centred on the measured rails, inside the walkable strip, and short enough to keep Billy's sprite on screen. |
| Grab and climb | Up at the base starts CLIMB on that tick, snaps x, climbs 0.8 px per tick, raises the visuals from their grounded offset, keeps the body on the ground plane, presents the paused `climb` clip with distance-driven poses that repeat in order, and makes the hurtbox invulnerable. |
| Clamp and dismount | The top rung clamps the climb; down climbs back by the same step and steps off at the base with `climb_finished` once, visuals grounded, vulnerability restored, and MOVE resuming on the same tick. |
| Rejections | Up 40 px beside or 30 px below the base walks instead of grabbing; an airborne Billy cannot grab but grabs on landing; attack, kick, and jump presses on the ladder neither fire nor survive the dismount; a punch on the ladder is rejected without damage or dismount. |
| Regressions kept | All eight suites pass through the runner; editor import, 240-frame main scene, and `git diff --check` clean. |
| Independent audit | Herdr-hosted reviewer (four runtime probes in the real level) returned BLOCK on one high and four mediums plus four lows. All nine are fixed with regressions: sideways step-off now fires within one step of the base; the grab snaps y as well as x so the top of the climb is absolute; the encounter closes every ladder and takes Billy off one; the dropped-input slice queues each action alone and lands the last one a tick before the base; every climb slice now runs inside the real level; a freed ladder steps Billy off; the head-clearance check loads the player scene and reads the camera's view top; `pose_index()` takes the sprite's frame count; and the grab-zone note was corrected. The reviewer also found a defect outside this scope (see below). |
| Ledge art | The stage slice `1232x272+0+208` drawn at y −56; the ledge's surface read back out of the stage texture by the suite (black cap above, stone on it) so a future re-crop cannot silently move it; extraction idempotent. |
| Step onto the ledge | The top rung fires `platform_entered` once, leaves the ladder, holds the ledge's height, keeps the body on the ground plane at the ledge's depth, lands Billy's feet on world y 25, drops the CLIMB state and the climb poses, and keeps him invulnerable with collision layer 2 off. |
| Walking it | Right and left walk along the ledge with MOVE and IDLE; depth input away from a ladder does nothing; each end of the 501–831 span stops him instead of dropping him. |
| The crossing | Up the left ladder, along the cornice, down the right ladder to the street: the descent starts from the ledge's own height, centres on the far ladder's rails, and restores vulnerability and actor collision at the base. |
| Camera | The band starts on the ground plane, rises to `limit_top` while Billy is on the ledge with his head still on screen, and returns to the band when he leaves it. A climb-only ladder still clamps at its own height. |
| Encounter gate | Crossing the trigger along the ledge leaves the fight idle and Billy on the cornice; returning to the ground plane past the trigger arms it on the next tick. |
| Regressions kept | All eight suites pass; editor import, 240-frame main scene, extraction idempotency, and `git diff --check` clean. |
| Real renderer | Eleven windowed captures of the whole loop — climb, stand, walk, far ladder, descent, street — probe script removed afterwards. |
| Chain-reset defect (outside ladder scope) | The audit found `HitReactionComponent.physics_tick()` was only called while incapacitated, so `hit_chain_reset_frames` never counted down and `consecutive_hits` never decayed for either actor. Both orchestrators now tick it every frame, with a Williams-suite regression asserting the chain resets after recovery. |
