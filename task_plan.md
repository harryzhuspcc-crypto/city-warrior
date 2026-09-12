# Task Plan: Correct Directional Head-Attack Animation

## Goal

Make rapid Right, Right play and move rightward using reference pose 1 → attacking pose 2 → ending pose 1, then return to normal right-facing presentation. Rapid Left, Left must be the mirrored leftward counterpart.

## Phases

- [complete] Phase 1 — Preserve the clarified reference and add failing sequence/direction regressions.
- [complete] Phase 2 — Correct head-attack pose scheduling and artwork-facing metadata.
- [complete] Phase 3 — Validate both directions, movement/hit behavior, all smoke suites, and the main scene.

## Scope Decisions

- Keep the existing two unique extracted textures; reuse pose 1 as the third SpriteFrames entry.
- Align pose 1 with startup, pose 2 with active frames, and pose 1 again with recovery.
- Treat the supplied artwork as authored rightward. Right uses it unflipped; Left mirrors it.
- AttackData remains authoritative through `animation_frame_starts = [0, 5, 10]` and `animation_facing_multiplier = 1`.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| None yet. | — | — |

## Completion Evidence

| Requirement | Evidence |
|---|---|
| Right sequence | Right, Right displays unmirrored pose 1 on frames 0–4, pose 2 on active frames 5–9, pose 1 again on recovery frames 10–19, then returns to normal right-facing presentation. |
| Left counterpart | Left, Left runs the identical schedule mirrored, travels/hits left, and retains normal left facing afterward. |
| Directional gameplay | Focused runtime probes verify exactly 20 px travel and correctly directed physical hits/knockback in both directions. |
| Texture reuse | SpriteFrames entries 0 and 2 reference the same imported `head_attack_00.png` texture. |
| Input semantics | Existing inclusive 12-frame same-direction double-tap tests remain green. |
| Final validation | Configuration, import, five smoke suites, main-scene startup, diagnostics, and `git diff --check` pass. Independent audit reports PASS. |
