# Task Plan: Double Dragon Prototype Steps 1–3

## Goal

Implement sections 1–3 of `docments/double-dragon/plan.md`: import and prepare initial artwork, create the feature-oriented project structure, and build an isolated Godot player scene with typed component boundaries.

## Phases

- [complete] Phase 1 — Copy source sheets into the project, create transparent working sheets, extract a minimal Billy animation set, and configure pixel-art imports.
- [complete] Phase 2 — Create the feature-oriented folders and shared data/component scripts needed by the player scene.
- [complete] Phase 3 — Build `player.tscn`, a standalone F6 test scene, project input actions, and validate with Godot CLI.
- [complete] Phase 4 — Audit every requirement and record verification evidence.

## Scope Decisions

- Only extract the minimal animations needed to establish the pipeline: idle, walk, punch, hurt, knockdown, and death.
- Use `AnimatedSprite2D` as the sole visual animation authority for this phase.
- Build structural combat/health components but defer functional combat, enemy AI, and level behavior to later plan steps.
- Keep source sheets under `assets/source_sheets`; generated transparent sheets and cropped frames live under `assets/sprites`.
- The player scene must run independently without an autoload.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| Repository is not initialized as Git, so `git status` failed. | 1 | Continue with filesystem-based verification; do not initialize Git without user request. |
| Headless scene run reported missing custom InputMap actions after the configuration script returned success. | 1 | Runtime `InputMap` mutations were not serialized. The tool now writes `input/*` dictionaries through `ProjectSettings`; the next run completed without diagnostics. |
| Player smoke test found that Godot 4.7 `AnimatedSprite2D` has no `advance()` method, despite the referenced guidance suggesting it. The injected attack event also did not reach the expected test path. | 1 | Replaced `advance(0)` with `set_frame_and_progress(0, 0.0)`. |
| Smoke test released synthetic attack input immediately after `physics_frame`, before player nodes processed that tick. | 2 | Keep the action pressed across two physics-frame boundaries before asserting/releasing. |

## Completion Evidence

| Requirement | Evidence |
|---|---|
| Step 1: import source artwork | `assets/source_sheets` contains all 13 PNG sheets and `.gdignore`; audit reported `source_sheets=13` and no source-sheet import artifacts. |
| Step 1: prepare a minimal animation set | `tools/extract_billy_frames.sh` reproducibly removes the Billy matte and generates 16 RGBA frames across six animation folders. Every generated frame validated as 80×80 RGBA, and the final contact sheet was visually reviewed. |
| Step 1: pixel-art project configuration | `project.godot` contains a 384×216 viewport, integer stretch, nearest canvas filtering, pixel snapping, and a 60 Hz physics target (default-valued settings may be omitted by Godot serialization). |
| Step 2: feature organization | `features/README.md` documents the feature boundaries; actor common/player folders contain typed data and worker components, while future enemy/combat/encounter/HUD/level folders exist. |
| Step 3: player scene | `features/actors/player/player.tscn` is a CharacterBody2D composition with body collision, Visuals/AnimatedSprite2D, hurtbox, hitbox, health, movement, combat, input, and state-machine components. |
| Step 3: animations and controls | `billy_sprite_frames.tres` defines idle, walk, punch, hurt, knockdown, and death; `project.godot` contains eight semantic InputMap actions. |
| Step 3: independent runtime | Final Godot 4.7 import and main-scene runs exited 0 with no ERROR/WARNING diagnostics. `tools/smoke_test_player.gd` reported `PLAYER_SMOKE_TEST_PASS` after validating health initialization, all six animations, movement, attack entry/completion, and return to idle. |
