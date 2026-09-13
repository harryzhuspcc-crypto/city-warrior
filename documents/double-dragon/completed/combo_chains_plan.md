# Task Plan: Section 9 — Hit-Confirmed Combo Chains

The previous plan (ladder climbing and the SCOOP ledge) is complete; it is kept
in `documents/double-dragon/completed/ladder_and_ledge_plan.md` and recorded in
`progress.md` and `findings.md`.

## Goal

Plan item 9.1 and its paired deferred requirement: Billy's three-hit punch
sequence from `documents/double-dragon/references/three-hit-punch.png` and the
three-hit kick sequence from `three-hit-kick.png`. The first two connected
inputs advance the chain; only the third uses the finisher — the rising
uppercut for punches, the turning kick for kicks. **Progression is driven by
confirmed enemy hits**: a whiff must not advance the chain.

## Agreed test seams

- `AttackChainComponent`: `index`, `next_attack(chain)`, `confirm_hit(attack)`,
  `finish_attack(attack, completed_naturally)`, `physics_tick()`, `reset()`,
  `is_open()`. Owns the chain step and the window that keeps it open; it never
  touches combat state.
- `Player`: `punch_chain` / `kick_chain` exports, the attack and kick buffers
  start the chain's current step, and a failed start resets the chain.
- `AttackData`: `billy_punch_cross` (step 2) and the two finishers
  `billy_uppercut` / `billy_turn_kick`, each with its own pose schedule.
- Billy `SpriteFrames`: `punch_cross` (3 poses), `uppercut` (4), `turn_kick`
  (5), all feet-pivoted like every other Billy pose.
- `FighterStats.chain_window_frames`: how long the chain stays open after a
  connected hit.

## Phases

- [complete] Phase 1 — Red baseline `tools/smoke_test_combo.gd`, registered in the runner.
- [complete] Phase 2 — Extract the nine new poses; add the three animations.
- [complete] Phase 3 — `AttackChainComponent`, the three AttackData resources, `FighterStats.chain_window_frames`, player wiring.
- [complete] Phase 4 — Punch-chain slices green: advance on hit, whiff resets, window expiry resets, interruption resets, finisher knocks down and wraps.
- [complete] Phase 5 — Kick-chain slices green; mixing punches and kicks breaks the chain.
- [complete] Phase 6 — All suites, editor import, main scene, `git diff --check`; plan, findings, progress, GenUI summary.

## Scope Decisions

- The punch chain is `punch` → `punch_cross` → `uppercut`. The sheet's punch
  band authors the same punch twice with alternating arms (poses 0-2 are
  pixel-identical to poses 6-8), so step 2 is the other arm and the chain reads
  as a real combo rather than one pose played twice.
- The reference strip's first pose is pixel-identical to `punch_02`, the
  existing punch's retract. The uppercut is authored as all four poses of the
  reference so the finisher is self-contained: wind-up, coil, rise, overhead.
- The kick chain is `kick` → `kick` → `turn_kick`. The sheet authors only one
  basic kick, so both openers use it; the finisher is the five-pose turning
  kick the reference shows.
- Both finishers knock down. The chain needs a payoff, `HitReactionComponent`
  already implements `knocks_down`, and it matches the arcade original.
- The turning kick does not reverse Billy's facing. Its rear poses are a spin
  through, not a turn to face the other way — unlike the back kick, which
  reverses deliberately.
- The chain is player-only. Williams has no chain, and `CombatComponent` keeps
  knowing nothing about chains: it reports hits and finishes, and the chain
  component decides what that means.
- Every step after an opener carries a short forward lunge over its startup.
  This was not planned: rendering the chains in the real level showed both
  finishers whiffing, because a landed hit knocks the target back about 10 px
  for a punch and 16 px for a kick. The lunge cancels the previous step's
  knockback rather than adding reach, so the openers are untouched.
- A chain step is requested with the attack the chain hands out, so switching
  from punches to kicks (or landing any non-chain move) breaks the chain
  through the same code path as a whiff.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| Red baseline: the chain seams do not exist | 0 | Expected red; resolved by the implementation. |
| `Parse Error: Cannot infer the type of "error"` from `Callable.call` | 1 | A slice list returns Variant; the loop variable is declared `String`. |
| `WILLIAMS_SMOKE_TEST_FAIL: Knockdown punch did not finish` | 1 | Billy's third punch is now the uppercut (26 frames, not 18). Those slices are about the target's consecutive-hit rules, so each press there is an explicit fresh opener. |
| Both finishers whiffed in the real level | 1 | The openers knock the target back ~10 px (punch) and ~16 px (kick). Every step after an opener now lunges forward over its startup. |
| The suite had not caught that whiff | 1 | It pressed the next step four frames after the previous attack, while the knockback slide still had ten frames to run. The reach slice now waits until the target leaves its reaction, capped by the chain's own window. |
| The reach slice failed on the wrong assertion | 2 | A dummy hurtbox parked on Billy satisfied `hit_landed` even for a whiffed finisher. Reach is now read from the intended target's health. |

## Completion Evidence

| Requirement | Evidence |
|---|---|
| Art | Nine new feet-pivoted 80x80 frames — `punch_cross` 3, `uppercut` 4, `turn_kick` 5 — each sliced from its own measured bounding box; all 44 existing frames byte-identical and the extraction idempotent. The pivot audit covers every animation, so the new poses are held to the same floor contact and feet midpoint. |
| Chain state | `AttackChainComponent` advances only on a confirmed hit and resets on a whiff, an interruption, a different chain, or a lapsed window; the finisher spends the chain. Verified by mutation: dropping the hit-confirmed condition fails the whiff slice. |
| Punch chain | Three connected punches present `punch`, `punch_cross`, `uppercut` and use the chain's own steps. |
| Kick chain | Three connected kicks present `kick`, `kick`, `turn_kick`. |
| Hit-confirmed | A whiffed opener leaves the chain on its opener; a whiffed cross drops it back. |
| Mixing | A kick after a connected punch opens the kick chain, and returning to punches starts that chain over. |
| Reach | Both chains land all three steps on a Williams who takes the full knockback and is pressed only once he stops sliding; verified by mutation to fail without the lunge. |
| Knockdown | Each finisher knocks a fresh Williams down on its own account, not merely as a third consecutive hit. |
| Real renderer | Both chains captured frame by frame in the prototype alley: every step lands and the target ends on the ground. Probe removed afterwards. |
| Regressions kept | All nine suites pass through the runner; editor import clean with `billy_stats.tres` unchanged, 240-frame main scene, extraction idempotency, and `git diff --check` clean. |
