# Task Plan: Double-Height Jump and Basic Kick

## Goal

Double Billy's current jump apex and implement the supplied two-pose basic kick as an L-bound, data-driven attack without adding combo progression.

## Phases

- [complete] Phase 1 — Add red-capable regressions for a ≥50 px jump apex, L-to-kick binding, two kick frames, and kick attack entry/completion.
- [complete] Phase 2 — Tune jump physics to approximately double the prior 25–27 px apex without changing the ground-plane model.
- [complete] Phase 3 — Extract the exact kick poses, add kick `AttackData`, generalize combat attack selection, and wire L input/presentation.
- [complete] Phase 4 — Validate punch/kick coexistence, hitbox timing/damage, buffering, all smoke suites, main scene, and visual assets.

## Scope Decisions

- J remains punch; L becomes kick.
- Keep the `grab` action reserved but remove its L binding to avoid action conflicts.
- Implement only the basic kick, not hit-confirmed combo progression.
- Combat timing remains authoritative; `AnimatedSprite2D` remains presentation only.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| None yet. | — | — |
| Multi-file regression patch partially applied because the player smoke test's animation list had changed since the expected context. | 1 | Read only the failed test file and inserted kick action, animation, entry, selection, and completion assertions against its current structure. |
| Initial kick regression could not infer an integer through a not-yet-existing dynamic `current_attack_data` property. | 1 | Explicitly type `kick_total_frames` as `int` so the red test reaches the missing kick action instead of failing at parse time. |
| Independent sign-off found a final-frame jump buffer was consumed before landing eligibility and real same-tick input events were replayed in fixed polling order. | 1 | Added exact pre-landing and `_unhandled_input`+polling regressions before changing input/physics ordering. |
| The new real-input priority test left global `just_pressed` state active while the next integration test manually simulated many physics ticks in one process frame, repeatedly refreshing its buffer. | 1 | Reset capture state and await one process frame between the real-input probe and manual-tick integration test. |

## Completion Evidence

| Requirement | Evidence |
|---|---|
| Double-height jump | Billy's 252.4 px/s takeoff with 600 px/s² gravity reaches exactly 51.00 px at 60 Hz, twice the measured 25.50 px baseline; constrained apex regression passes. |
| L-bound kick | `kick` is bound to physical L, J remains punch, and `grab` is unbound in both `project.godot` and idempotent `configure_project.gd`. |
| Referenced animation | `kick_00`/`kick_01` are clean 80×80 chamber/extension frames visually matched to the supplied reference; texture identity/order and pivot checks pass. |
| Data-driven attack | `billy_kick.tres` defines 6 startup, 4 active, 12 recovery, 15 damage, 18 hitstun, knockback, and hitbox geometry. `CombatComponent` latches requested attack data while retaining punch as default. |
| Phase-aligned presentation | Kick chamber is shown during startup and high extension begins with the active hitbox frame; regression verifies both poses. |
| Physical fighting behavior | Real Area2D overlap applies exactly one punch and one kick with their respective damage; target deduplication and later lethal-cancellation behavior remain green. |
| Input interactions | Punch/kick use a latest-request effective slot; jump is finite-buffered, valid on the final pre-landing frame, and ground attacks cannot run invisibly while airborne. |
| No combos | No combo counter/progression exists; the previously documented hit-confirmed combos remain deferred. |
| Final validation | Idempotent extraction/configuration, Godot import, four diagnostic-aware smoke suites, and main-scene run all exit 0 with no diagnostics or debug tags. Independent final audit reports PASS with no high/medium blockers. |
