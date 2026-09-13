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

## Billy's four special moves

- Preserved the four new clipboard references as `documents/double-dragon/references/elbow.png`, `head-attack.png`, `back-kick.png`, and `jump-kick.png`.
- The references use an altered 16-color palette/matte, but their binary silhouettes match the source sheet exactly. Raw-mask matching located every pose without relying on approximate visual crops.
- Exact trimmed source bounds: elbow `(435,357) 22×62`, `(465,356) 34×63`; head attack `(531,362) 24×57`, `(563,360) 32×59`.
- Back-kick sequence uses repeated jump poses followed by unique rear-kick poses: `(16,435) 28×64`, `(52,460) 37×39`, `(436,440) 22×59`, `(466,437) 39×62`, `(513,451) 26×48`.
- Jump-kick sequence is `(121,437) 24×62`, `(153,435) 28×64`, `(189,460) 37×39`, `(234,455) 44×44`, `(286,460) 37×39`.
- Rear attacks need attack-facing and hit-facing to be distinct. `AttackData` should own a ±1 hit-direction multiplier; CombatComponent should latch facing and mirror geometry/knockback by the resulting hit direction.
- The existing finite buffers can support grounded chords if press frames are tracked; double-tap detection additionally needs movement-edge event capture so physics polling does not count one physical press twice.
- Head attack should use the tapped direction as its facing and include short data-driven forward travel; all other requested moves keep the current ground position behavior except normal airborne movement during jump kick.
- Architecture audit caught command-order hazards. To support either key order within three ticks, grounded singles must wait for the chord window rather than immediately mutating jump/combat state.
- Combat needs a natural-vs-canceled finish result before clearing its latched AttackData; otherwise back kick would reverse Billy on death or test cleanup.
- Actor facing, hit direction, artwork's native direction, and travel direction are independent. AttackData will represent hit and artwork multipliers while CombatComponent latches actor/travel facing.
- Attack movement must precede overlap resolution for the same authoritative attack frame; otherwise a head-attack target reached on the final active movement tick can be missed.
- All special pose changes should be driven by explicit AttackData frame-start schedules and `AnimatedSprite2D.set_frame_and_progress()`, not free-running playback.
- Implemented special recognition inside PlayerInputComponent: order-independent three-frame chords, mutually exclusive attack singles, a 12-frame same-direction tap sequence, and movement-event capture guards.
- AttackData now owns rear-hit direction, native artwork direction, natural-completion reversal, jump launch/air-control flags, movement window/speed, and authoritative pose-start ticks.
- Player physics now moves once before CombatComponent resolves the current active overlap, preserving the final moving active frame for head-attack collision.
- A regression with a hurtbox reachable only on head-attack frame 9 proved Area2D's cached overlap list still lagged current-frame movement. Active attacks now use `PhysicsDirectSpaceState2D.intersect_shape()` at the hitbox's current global transform, while per-attack target deduplication remains unchanged.
- Generated-frame montage visually confirms all 14 transparent 80×80 outputs preserve the supplied pose order with clean silhouettes and no neighboring-sheet fragments.
- Strengthened regressions now cover both chord key orders, inclusive/exclusive window boundaries, single fallback, 12-frame double taps, event/poll deduplication, cancellation-safe back-kick facing, both rear-hit geometry directions, exact 20 px head travel, full jump trace equality, landing-tick classification, air control, front-target exclusion, and final-active physical contact.
- Follow-up audit found airborne K+L was being consumed into a grounded-only back-kick chord before Player could see L. The airborne router now treats that chord as jump kick in either key order.
- Newly activated aerial attacks now retain air movement on their activation tick, and final recovery completion selects locomotion before movement so MOVE cannot render with an extra zero-motion hitch.
- Adding `-strip` to both clean-sheet and final-frame output removes ImageMagick timestamp chunks. Two isolated extraction runs now produce byte-identical SHA-256 manifests for all generated PNGs.
- Final hardening made CombatComponent lifecycle signals re-entrancy-safe: logical state is finalized before emission, start aborts cleanly when startup listeners cancel, and finish listeners cannot double-finish or start inside the old transition.
- Hit resolution latches AttackData before calling target code, so a target-side `hit_received` listener may cancel the source without turning the later `hit_landed` payload null.
- One-shot action polling was removed in favor of `_unhandled_input`, preserving GUI consumption. Per-action held physical-input IDs ensure A+Left Arrow together are one semantic LEFT edge rather than a false double tap.
- Final independent completion audit reports PASS with no high/medium blockers.

## Aerial kick landing hold

- The new references isolate pose index 3 from each five-pose sequence: jump kick's forward extension and back kick's rear extension.
- Current fixed durations (jump kick 24 ticks, back kick 30 ticks) can finish before the approximately 50-tick 51 px jump arc, causing normal jump presentation to resume in midair.
- The requested “kicking status” is treated as gameplay state as well as presentation: retain ATTACK/ACTIVE, the extension pose, and the deduplicated hitbox until JumpComponent reports grounded.
- CombatComponent should receive current airborne eligibility from Player rather than referencing JumpComponent directly, preserving component reuse and explicit orchestration.
- Red regression reproduced the issue during back-kick descent: the move had already entered recovery/finished instead of retaining ACTIVE.
- `landing_hold_frame` equals the extension pose's schedule start (back kick frame 10; jump kick frame 8). Combat progression clamps there while airborne, repeatedly queries the active volume with target deduplication, and completes naturally when Player passes grounded state.
- Player checks landing completion before attack movement, allowing CombatComponent to finish/reverse and normal locomotion to resume on the landing tick without an extra zero-motion frame.
- Completion audit exposed two ordering hazards unique to a landing-held ACTIVE attack: a landing callback could introduce a target before the old active query, and a re-entrant callback could replace the attack while the stale tick continued.
- Grounded landing completion now occurs before any ACTIVE query. Combat also snapshots an attack-generation token, so cancellation/replacement invalidates every remaining operation from the old tick even when the new attack uses the same resource.
- Final independent audit reports PASS: both aerial kicks hold ATTACK/ACTIVE/pose 3 and physical hitbox through descent, deduplicate held contact, finish without a post-landing hit, and preserve cancellation-safe reversal.

## Quarter-height back kick

- Baseline regression measured the back kick at the full normal-jump apex of 51.00 px; the requested quarter height is 12.75 px.
- Halving takeoff speed is only a continuous-physics approximation and produces 12.24 px under the project's semi-implicit 60 Hz integration, not an exact quarter.
- `AttackData.jump_height_scale` now expresses the designer-facing ratio. JumpComponent deterministically solves the takeoff velocity against its actual fixed-step integrator, producing 12.75 px without changing the configured normal takeoff speed.
- Back kick still reaches landing-hold frame 10 before descending, so its ATTACK/ACTIVE/hitbox/pose guarantees remain intact over the shorter arc.

## Directional head-attack correction

- The clarified reference identifies its first image as both startup and ending pose, while the second image is the attacking pose.
- The extracted textures were already correct, but the resource schedule `[0, 5]` held attacking pose 2 throughout recovery and `animation_facing_multiplier = -1` incorrectly treated the supplied art as leftward.
- SpriteFrames now intentionally contains three entries backed by two unique textures: pose 1, pose 2, pose 1. AttackData aligns them with startup frame 0, active frame 5, and recovery frame 10.
- The supplied artwork is authored rightward: Right, Right displays it unflipped and moves/hits right; Left, Left mirrors it and moves/hits left. The latched attack direction becomes normal facing after recovery.

## Williams enemy

- `williams.png` is 616×1678 with matte RGB `(115, 141, 165)` / `#738DA5`, a different matte from Billy's sheet.
- Visual layout: row 1 (y≈45–110) holds an idle pose, a four-frame side walk, and a four-frame rear walk; row 2 (y≈125–190) holds the punch sequence; rows around y≈295–370 and y≈645–710 hold hit reactions and fall/prone poses.
- The player scene wires no listener to `HurtboxComponent.hit_received`, so Billy currently takes damage without hitstun, knockdown, or knockback; only death is handled.
- Player collision contract confirmed from `player.tscn`: body layer 2 mask 1+2; hurtbox layer 3 (value 4) monitorable only, mask layer 6 (value 32); hitbox layer 5 (value 16) mask layer 4 (value 8).
- Williams pose map (source bounds, `WxH+X+Y`): idle `26x63+8+44`; side walk `26x63+74+44`, `17x62+108+45`, `20x63+133+44`, `26x62+161+45`; rear walk `24x60+227+47`, `24x61+259+46`, `21x61+291+46`, `21x60+320+47`.
- Williams punch row: wind-up `28x60+8+131`, extended `46x60+44+131`, second wind-up `29x59+98+132`, second extension `46x59+135+132`, guard/recover `28x59+189+132`. The first three poses give a startup → active → recovery schedule.
- Williams reaction row (y≈643–706): recoil `27x63+8+643`, upright stagger `24x63+75+643`, doubled-over `23x53+139+653`, falling backward `47x46+202+660`, landing on back `47x32+257+674`, prone `48x30+312+676`, kneel-up `30x43+368+663`. Prone doubles as the death pose.
- Connected-component analysis with a one-pixel area threshold found no detached fragments in the idle/walk, punch, or reaction rows, so exact bounding boxes padded by two pixels isolate every chosen Williams pose.
- The shared `tools/lib/frame_extraction.sh` reproduces Billy's frames byte-for-byte (clean `git status` after regeneration), so both manifests now share one feet-pivot implementation.
- All 19 generated Williams frames pass the 80×80 edge and floor-contact audit (midpoints 39.5–40.0), including the wide prone and falling poses.
- Hits land inside the attacker's physics tick, which can run after the victim already synced presentation for that tick. Reaction poses therefore sync immediately from `_on_reaction_started`; knockback movement still waits for the victim's own tick.
- Each Billy punch knocks Williams roughly nine pixels back, so consecutive punches whiff unless Billy steps forward; the smoke test repositions Billy rather than weakening the knockback.
- GDScript lambdas that capture a node freed before the lambda runs emit `Lambda capture ... was freed`, which the diagnostic-aware runner treats as a failure; tests must capture instance ids for nodes that free themselves.
- `EnemyAIComponent` latches `reaction_delay_frames` in `_ready`, so `set_target()` restarts the delay; this also gives Step 7 spawns a natural wind-up.
- Self-audit: the enemy cooldown originally counted from the attack request, leaving only eight frames between a 32-frame punch and the next; it now restarts when the punch finishes so the gap equals `attack_cooldown_frames`.
- Self-audit: health can reach zero without a hurtbox hit (direct `take_damage`, future hazards). `HitReactionComponent.begin_death()` lets both orchestrators start the fall, invulnerability, and linger from their dead branch in that case.
- The Agent tool cannot open iTerm2 panes in this Herdr session; independent audits must be hosted through the Herdr skill.
- Independent audit (Herdr-hosted): in the live loop every hit lands through `CombatComponent._on_hitbox_area_entered` during the physics server's query flush at the start of the next tick, before either actor's `_physics_process`; the `intersect_shape` path only catches targets that move into an already-active hitbox within the same tick. All physics mutations reached from those callbacks are deferred.
- Audit MEDIUM: the two 14×8 body colliders stop a pure vertical `move_and_slide` at about 8 px of depth, so a 6 px depth tolerance was unreachable whenever Billy stood within 14 px horizontally. The AI now sidesteps out of `body_clearance_x` (16 px) before adjusting depth instead of raising the tolerance, which would have let Williams punch through empty air at dx = 0.
- Audit lows fixed: a null target with a player in the tree was not passive (now `acquire_player_target` gates the group fallback, which also retries every tick so tree order no longer matters); Williams kept punching a dead Billy (the orchestrator now passes `can_act = false` when the target reports `is_dead()`); `hit_chain_reset_frames = 0` never reset the chain; the optional hurtbox export silently dropped knockdown invulnerability (now required); cancelling before starting the reaction produced a one-tick IDLE between ATTACK and HITSTUN; Billy rendered MOVE on the recovery tick while still sliding (the incapacitated branch now falls through to locomotion when recovery happens); retreat into a wall walked in place (ends on `is_on_wall()`).

## Prototype level encounter

- `new-york-20xx.png` is a 5216×736 transparent composite. The first street section (garage, poster wall, SCOOP MOTO building, barrel alley) occupies columns 0–1215 before a rubble wall; its opaque rows span 160–479, the road's last row is 479, and the sidewalk line sits near row 416. The stage slice was therefore `1232x216+0+264` so the road bottom meets the viewport bottom; it later grew upward to `1232x272+0+208` for the ledge's headroom (see Ladder climbing), keeping that same bottom row.
- Static bodies parented to the camera move with it, so screen-edge walls need no per-tick repositioning; the camera ticks after the player in tree order, so a wall's new position first matters to Billy's move on the next tick, and the follow keeps the walls 192 px away so that lag never shows. Keeping them on a dedicated layer (8) that only Billy masks lets enemies spawn and walk in from off screen through those walls.
- Triggering the encounter when Billy reaches the lock x means the following camera is already centered there; locking never jumps the view. The audit reproduced the trap a backward lock would cause (the view pans back, the right wall's outer face then keeps Billy off screen forever), so `lock_at` now honors forward-only scrolling and clamps every lock so the target stays at least `target_margin` inside the view.
- `Input.action_press` issued between physics frames from a SceneTree script is visible to `Input.is_action_just_pressed` inside the next `_physics_process`, which makes the restart prompt testable without synthesizing input events.
- `SceneTree.current_scene` can be assigned from a `--script` run, after which `reload_current_scene()` swaps in a fresh instance and frees the old level within a frame. Waits spanning the reload must capture instance ids, not the level node, or the runner sees `Lambda capture ... was freed`.
- Teleporting Billy past the lock x inside a camera-only slice starts the encounter and locks the camera, so pure camera slices must disable the controller first.
- A live three-Williams fight against an idle Billy takes roughly 800–900 physics frames at real-time pacing, which would crowd the runner's per-suite budget; the soak slice pre-damages Billy so two punches finish him, keeping the whole encounter suite near 12 s.
- The global git `indent-with-non-tab` whitespace rule flags any edited Python line indented eight or more spaces, so `git diff --check` stays clean only when runner edits avoid deeply indented lines.
- With position smoothing and physics interpolation off, `Camera2D` refreshes the viewport transform from its transform-changed notification, so a camera positioned in `_physics_process` frames the same x under either process callback (audit probe: 11/11 samples matched in both modes). The belt camera keeps the default; switch to the physics callback only if physics interpolation is enabled.
- A hard follow re-centers on Billy in one tick after an unlock, a jump of up to 185 px (48 % of the screen) whenever the last enemy falls with Billy at an edge. The camera now paces every move at `catch_up_speed` (180 px/s, twice Billy's walk), so the unlock pans back to him over about a second.
- A paced pan is only safe while the target is inside the view. When a teleport left Billy beyond the right edge, the right wall swept into him at 3 px per tick, `move_and_slide` depenetration pushed him ahead of it, and the follow chased his new position: a runaway that carried him to x 1255, through the level boundary. The cap therefore applies only while the target lies within the view; a target outside is cut to at once.
- Counting only `defeated` would lock the camera forever if an enemy ever left the tree another way (a hazard, a despawn, a weapon). The controller now tracks spawned enemies by instance id and counts each down once from either `defeated` or `tree_exiting`, ignoring the teardown case where the controller itself is leaving the tree.
- A disabled encounter now reports cleared while idle so the exit can finish a level played without the fight, and reinforcements stop spawning once the player reports `is_dead()`.


## Ladder climbing

- Billy's sheet by the band each extraction actually uses: idle y 8; the side walk and the rear walk share y 88; the rear climb strip is y 174–235 (its `REPEAT` label at y 244) with three front-facing poses to its right; punch y 270; kick y 350; jump and the back/jump kicks y 430–460; the second `REPEAT` row at y≈515 is a side-facing fighting walk; hit reactions and fall/prone poses around y 920.
- The climb cycle is the five-pose rear view above the sheet's **first** `REPEAT` label, band y 174–235 at x 16, 46, 78, 110, and 139. The first attempt took the row above the second `REPEAT` label at y≈515 instead, which an earlier note in this file already called a side-facing four-frame repeat row at y≈510: Billy climbed the ladder in a fighting stance facing sideways.
- Those five poses plant their feet on five different rungs, so the shared feet-pivot extraction (which centres each pose on its own floor contact) swings the body sideways as the lifted leg changes. `extract_anchored_frame` composites them untrimmed instead: the strip's own bottom row becomes the floor contact and the head's centroid — the one part that holds still on a ladder, at sheet x 23/55/89/118/149 — lands on the 80×80 pivot. `tools/smoke_test_step_4.gd` exempts `climb` from the feet-midpoint check for that reason and the ladder suite asserts the head pivot in its place.
- The rails read as full-height bright runs in pixel columns 513 and 529 of the stage slice, confirming the 513.5/529.5 centres recorded below; Billy's head lands half a pixel right of the ladder's 521.5 centre at 522. His body is a three-quarter rear view whose visible bulk leans left of the head, so the right rail shows beside him while the left rail hides behind him; that asymmetry is in the source art, not the alignment.
- The left SCOOP ladder's rails sit at stage-slice x 513.5 and 529.5, so its centre is x 521.5; its rungs run from y 33 to 136 and the rails end at 143, well above Billy's highest feet line of 160 (he stands in front of the wall, as belt-scrollers intend). The building's second ladder is at x 769.5/785.5, centre 777.5 — an earlier note here put it "around x 609", which is the SCOOP sign, not a ladder. A drainpipe at x 838–865 marks the end of the building's front face.
- The ladders lead to the building's stone cornice, and both of them do, which is what makes it a crossing rather than a dead end. Its black cap line is sheet row 288 and its stone starts at 289; the corbel run spans sheet x 493–810 with the flat band continuing to the drainpipe at 838. In the stage slice the surface is world y 25, so a climb from either base at y 160 is 135 px.
- The player's `Visuals` node rests at (0, −40); climbing adds the climbed height to that offset. Tests must compare against the grounded offset, not zero.
- The grab zone spans 8 px above to 12 px below the base. The part above the base is unreachable in the shipped level: the body collides with the strip's top boundary in the air as well as on the ground, so Billy pins at the base line whether he walks or jumps into it. The original reason recorded here (jump drift) came from a test world that had no boundaries, which is why the climb slices now run inside the real level.
- Grabbing uses an immediate `intersect_point` against ladder areas on layer 9 from the player's physics tick, the same query style the combat component uses, so there is no one-tick sensor lag and enemies never interact with ladders.
- While climbing, `movement_component.stop()` keeps the body still and buffered attack, kick, and jump presses are cleared each tick, so nothing fires on the dismount tick; the dismount falls through to ordinary locomotion within the same physics tick.
- The feet-pivot library measured the foot band with ImageMagick `-trim`, which takes its background from the band's corner pixels. Climb pose 4's boot fills the band's left corner, so the trim read opaque as background and placed the pose 1.5 px off center. The band is now padded with a one-pixel transparent border before trimming; every previously generated Billy frame stays byte-identical, and Godot's import cache must be refreshed (editor import) before headless runs see regenerated PNGs.
- Snapping only x on the grab measured the climb from wherever in the 11 px grab band Billy happened to stand, so the top of a 96 px climb landed anywhere between feet y 64 and 75. The grab now snaps to the ladder's base, which makes the top an absolute world position. The body then rests a sub-pixel distance (Godot's physics safe margin, about 0.075 px) below the base, so tests compare the snap with a 0.2 px tolerance.
- `climb_height` is never observed at exactly zero while climbing: the grab tick immediately applies one step of up, and descending releases inside the down branch. A sideways step-off therefore has to trigger within one step of the base, not at exactly zero.
- The only ladder stands at x 522, inside the locked encounter arena (view 448-832), and climbing grants untimed invulnerability, so the fight could be sat out indefinitely with the camera locked. The level now closes every ladder on `encounter_started` and opens them on `encounter_cleared`, releasing anyone already on a rung; the ladder itself owns an `is_climbable` flag the level drives, so the player never learns about encounters.
- `HitReactionComponent.physics_tick()` was only called while an actor was incapacitated or dead, so the `NONE` branch that counts down `hit_chain_reset_frames` never ran: `consecutive_hits` never decayed and `hits_before_knockdown` behaved as a lifetime counter for both actors. Both orchestrators now tick the component every frame.
- Standing on the cornice needs headroom the old `1232x216+0+264` slice did not have: feet at y 25 put Billy's head at y −38, well above the band. The section's art is opaque from sheet row 192, but not at every column — rows 192–207 have scattered gaps and 208–223 are transparent for x 0–255, where the MATIN garage is shorter. Sheet row 208 is therefore the highest crop with no hole anywhere from x 300 rightwards, which is the whole span the raised view can cover while Billy is on the ledge. The slice is now `1232x272+0+208`, drawn at y −56 so every ground coordinate stays where it was.
- The camera's band rises by the target's own elevation, which holds Billy's feet on a constant screen row until `limit_top` (−56) stops the rise and he then climbs up the frame. At the top his feet are 81 px below the view's top edge and his tallest standing pose is 63 px, so 18 px of brick stays above his head. A jump is deliberately left out of `visual_elevation()`: a band that bobbed on every hop would be unreadable.
- `get_viewport_rect()` is not a usable source for the band's height. A headless run reports a square 384×384 dummy viewport, so the camera's vertical clamp — and every test that checks framing — was measuring a screen that does not exist. The width happened to match by coincidence. The camera now takes both dimensions from the project's design viewport, which is what the game actually renders under integer stretch.
- The top step ends the climb without ending the elevation, so a separate `is_on_platform` branch in the player's tick let the intervening fall-through reach `jump_component.physics_tick()`, which reset the visuals to the ground plane for one tick. Both the rung and the ledge are now ticked inside one `_process_elevated`, and only a return to the ground plane ends the tick early.
- Walking a ledge is x only. The body keeps the ground plane at the ledge's own depth line, so the ledge's origin and its ladders' bases must share a y; depth input up there is ignored, except that down over a serving ladder is the way back onto its rungs. That makes "down does nothing" true only away from a ladder — the first version of the walk slice pressed down while still standing over the ladder Billy came up and was taken straight back onto it.
- An elevated Billy now drops collision layer 2 as well as his hurtbox, because walking 330 px along the cornice passes over ground the arena's enemies stand on; before, an enemy body under the ledge would have blocked him in mid-air.
- The encounter's lock x (640) sits between the two SCOOP ladders (522 and 778), so crossing it along the ledge used to arm the fight and the level's `encounter_started` handler would then drop Billy off the cornice. The trigger now waits for a player on the ground plane, duck-typed through `is_elevated()` exactly as `is_dead()` already was. The handler's release still matters for a level that starts a fight any other way, so the suite drives it from the signal.
- Headless Godot paces physics to real time, so a suite's timeout is really a budget on simulated seconds. The ladder suite climbs 135 px at Billy's own 48 px/s a dozen times over and needs about 33 s; the runner's budget is now a named 120 s constant rather than a bare 30.
- A headless editor import once rewrote `features/actors/player/billy_stats.tres`, dropping every overridden value and writing `null` for its `PackedInt32Array` exports; the suites still passed because the dropped values matched the script defaults. Re-running the import after restoring the file did not repeat it, but `.tres` resources are worth a `git diff` check after any import that follows a change to their script.

## Hit-confirmed combo chains

- The sheet's punch band (y 262-352) holds twelve poses in four groups, and the third group is **pixel-identical** to the first: poses at x 16/53/107 and x 315/352/406 hash the same after trimming. So the band is punch, other-arm punch, punch again, then the uppercut — which is what makes the chain's second hit the cross rather than the same punch played twice.
- `three-hit-punch.png` matches the sheet at x 404, y 264 (`compare -subimage-search`, RMSE 0.046 against the un-matted sheet). Its four poses are the band's last four, and its first is byte-identical to `punch_02`, the basic punch's retract. The finisher is authored with all four so the animation stands on its own: wind-up, coil, rise, overhead.
- `three-hit-kick.png` matches at x 107, y 344 — five poses that are one continuous motion, not three kicks: step in, knee up, extended kick, spin, back turned. The sheet authors only one basic kick, so the chain's first two steps share it and only the finisher is new art.
- **A chain has to reach the enemy its own opener knocked away.** Measured in the real level from a 26 px gap: a punch pushes Williams about 10 px and a kick about 16 px, so the gap after two punches was 45.9 px and the uppercut (reach x 8-28) missed entirely; after two kicks it was 57.4 px and the turning kick missed. Every step after an opener now carries a short forward lunge over its startup — 120 px/s for 5 frames on the cross, 90 for 7 on the uppercut, 150 for 8 on the turning kick — which cancels the previous knockback almost exactly (the gap after the cross is again 35.9 px).
- That defect was invisible to the first version of the suite, which pressed the next step four frames after the previous attack ended: the knockback slide runs for the whole hitstun (14 frames for a punch, 18 for a kick), so the target had not finished sliding. The reach slice now waits until the target is out of its reaction — the furthest the next step can ever be asked to reach — capped by the chain's own window so a combo pressed that patiently still cannot lapse.
- A stationary dummy hurtbox parked on the player is a trap for any slice that asserts "the hit landed": `_resolve_current_overlaps` reports every overlapping hurtbox, so a whiffed finisher still emitted `hit_landed` from the dummy. Slices about reach read the intended target's health instead.
- Billy's chain broke two Williams slices that punch three times in a row, because the third punch became the uppercut and knocked down by itself. Those slices are about the target's own consecutive-hit rules, so each press there is now an explicit fresh opener; the combo's knockdown and `hits_before_knockdown` stay separately covered.
- The chain lives in its own component rather than in `CombatComponent`. Combat reports `hit_landed` and `attack_finished`; the chain decides what they mean, and only for the attack it handed out — so an elbow or a head attack landed mid-combo cannot earn the next punch, and switching from punches to kicks breaks the chain through the same path as a whiff.

## Stage music

- The arcade rip is twelve tracks, 21.6 MB of 64 kbps 44.1 kHz stereo MP3, and the durations match the album listing to the second. Stage 1's theme is track 2, `Slums (Arrival of the Black Warriors)`, 3:03. Files are named by track number and a short slug so the album's order survives in the folder; the full titles live in this section and in the suite's `SOUNDTRACK` table. Like the sprite and stage sheets, these are copyrighted reference assets for a local prototype, not material to ship.
- **Godot imports audio with `loop=false`.** A stage track left that way fails in the worst way available: the level plays normally and then goes silent three minutes in, long after anyone would connect the silence to the import. The six tracks that underscore open-ended play (opening, slums, Abobo, industrial, woods, headquarters) are imported with `loop=true`; the six fixed-length cues are left one-shot, since a cue that repeats plays over whatever follows it. `MusicPlayer` asserts the flag rather than trusting it, and the suite pins the whole table.
- Looping is checked as behaviour, not just as configuration: the suite seeks to half a second from the end of the stage track and waits for it to come round. Measured, it climbs to 183.03 s and returns to 0.06 s with `get_loop_count() == 1`, still playing.
- **The audio server starts and releases playbacks on its own mixing pass, not on a frame**, and a headless suite can outrun it in both directions. Tear a level down in the same instant it starts playing and the stop overtakes a start the server has not finished; quit in the same breath as the last `free()` and the server is still holding the stream. Godot reports either at exit as a leaked instance and a resource still in use — which the runner treats as a failure, so five suites went red for reasons that had nothing to do with the code under test. `tools/lib/audio_settle.gd` owns both waits. They are wall-clock (0.2 s) rather than frame counts on purpose: a frame count passes or fails by how fast the machine is running, which is exactly how this first went wrong — waiting 1, 2 or 3 frames leaked while 0 and 5 did not.
- That timing also invalidated a measurement mid-task: five "clean" runs of the music suite turned out to be five runs of a script that never loaded, because a parse error meant nothing executed and so nothing leaked. A suite that is green because it did not run looks exactly like a suite that is green.
- **Quitting the game while music plays trips Godot's exit leak report about half the time** — 3 runs in 5, with or without a `stop()` on the music node's `_exit_tree`, so it is an engine shutdown race rather than something game code can close. It costs a player nothing (the process is ending), but it does mean a 240-frame headless run of the main scene is no longer a clean-exit check while music plays. An `_exit_tree` override was written for this and then removed once measurement showed it changed nothing; the smoke suites are unaffected, because they settle explicitly.
- Verified on a real device rather than the dummy driver: CoreAudio at 48 kHz, playback position advancing, and −17.4 dB peaking on the master bus — signal actually reaching the output, not just a position counter ticking.
- `-6 dB` on the stage player is a starting level for music with nothing to balance against. The first sound effect is what will really set it, and that is also the moment to add a `Music` bus; with one sound in the game, a bus layout would be a seam with nothing on either side of it.
- MP3 loops carry the format's encoder padding at the seam, so a very short looping cue would need Ogg or WAV to be seamless. These tracks are minutes long and already a lossy 64 kbps, so re-encoding would lose a second generation to fix a seam nobody reaches; noted here as the fix if a loop point ever does become audible.
