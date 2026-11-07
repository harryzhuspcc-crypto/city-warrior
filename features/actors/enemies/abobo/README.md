# Abobo

Playable scene: `res://features/actors/enemies/abobo/abobo.tscn` (also safe to run alone).

## Encounter / balancing assumptions

`levels/prototype_alley/prototype_alley.tscn` chains **Opening → Middle → Ending → Boss**. Opening (trigger x=96) and middle (x=640) each spawn **three Williams**. Ending (x=1040) preserves its **three Williams** at (820,200), (800,176), and (780,168), and now adds **one Linda** at (1184,184). `BossEncounter` requires all four Ending enemies to clear, triggers at **x=1120**, and spawns **one Abobo** at `BossEntrance` **(928,184)**. Linda details: `../linda/README.md`.

Placement assumption: reuse the last screen rather than extend/crop new stage art. The world ends at x=1232; the 384 px camera clamps to center x=1040 (view x=848–1232), even when Boss requests lock x=1120. Abobo starts inside that reachable arena, behind Billy. The existing exit **(1192,184)** is beyond the boss trigger and inside the right world/screen walls. Every enabled encounter must clear before exit can finish the stage, including when Billy has already walked past the exit during a fight.

On **Boss activation**, the level replaces `02_slums.mp3` with `res://assets/audio/bgm/03_abobo_entrance.mp3` on the same `MusicPlayer` / Music bus at the existing -6 dB. The boss track already imports with looping enabled. No extra BGM player, overlap, fade, or new camera region is introduced. Boss clear alone leaves that track running; all four clears plus exit stop it and play non-looping `04_mission_complete.mp3`. Disabled/future encounters and dead Billy do not activate boss music.

Abobo has 140 HP, 52/36 px/s horizontal/depth speed, four-hit knockdown resistance, a 30-frame initial reaction delay and a 75-frame attack cooldown. These are prototype balance choices, not claims of arcade-exact behavior. Close, grounded, vulnerable, non-attacking Billy is throwable within 32 px / 6 px depth; otherwise Abobo uses a slower 12-damage punch. Jumping, attacking or changing lanes provides counterplay. Abobo cannot be hair-grabbed; the supplied sheet does not provide Williams-style captive poses.

## Architecture and throw contract

- The old Williams orchestration lives in `../common/enemy_fighter.gd`; Williams and Abobo are thin specializations. Existing movement, AI, combat, health, reactions, visuals, audio and encounter contracts are reused, not copied into a second large actor script.
- `../common/enemy_throw_component.gd` is an optional composed worker. It exclusively owns the pair and one physics-frame clock. Billy only suppresses ordinary actions and tracks his ground position while claimed. The normal jump component never drives throw height.
- At 60 Hz: Abobo poses at frames **0/8/16/24**; Billy hurt/carry before frame 16, inverted at 16, tumbling at 32, prone at **48**. Release at 24 launches a wall-clipped, 120 px **over-the-shoulder backward toss**, opposite Abobo's initial facing; frame 56 ends the prone hold. These timings and carry sockets are authored approximations from the static references.
- `res://assets/audio/voice/voice_05_abobo_throws.wav` plays **once at confirmed paired throw start (frame 0)**, after acquisition callbacks and ownership checks succeed. `abobo_throw.tres` opts into `plays_action_voice`; the existing `ActorAudioComponent.play_attack_voice()` routes the actor-local `ActionVoiceAudio` through **Voice** and emits `playback_requested`. Failed/blocked/competing/repeated-active attempts and fallback punches are silent. Flight, release, landing and recovery never replay it; a later successful throw gets a fresh request. An interruption after a confirmed start does not undo the voice already requested.
- One **24-damage** hurtbox hit commits at landing frame 48. Billy emits his existing ground-fall SFX 10 once, Abobo requests the confirmed punch-impact clip once. Existing death voices play through health signals. A lethal throw completes flight, then starts death prone without replaying another fall or landing sound.
- Both actors keep their world collision masks; only a temporary mutual body exception is added. Acquisition rejects obstructed alignment. Flight uses `move_and_collide`, with visual-only height and grounded Y-sort coordinates.
- Hit, direct reaction, death, removal, queued deletion, manual cancellation and normal completion share idempotent cleanup. References clear before callbacks, tree-exit hooks disconnect, collision exceptions and visual height restore, buffered actions clear. Interrupted launched victims settle once and normally enter existing prone/get-up recovery; interruption before launch releases without throw damage. The pair guards synchronous acquisition and release callbacks.

## Art / regeneration

The unchanged supplied source already exists at `assets/source_sheets/jick-abobo.png` and was byte-compared against `dd_assets/double-dragon/jick-abobo.png`.

```sh
bash tools/extract_abobo_frames.sh
bash tools/extract_billy_frames.sh
```

Requires ImageMagick and Python 3. The manifests generate transparent, nearest-filtered frames and resources. Abobo uses 96x96 canvases / visual offset (0,-48); Billy's new `being_thrown` frames retain 80x80 / (0,-40). Existing Billy PNGs remain unchanged. Full crop/pivot notes: `assets/sprites/abobo/README.md`.

## Verification

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot python3 tools/run_smoke_tests.py
```

`tools/smoke_test_abobo.gd` covers resources, independent health, both facings, exact pose/flight/damage/landing timing, input suppression, cooldown and live AI approach, fallback punch, eligibility, competing owners, reentrant acquisition, wall clipping, lethal landing, both-sided lifecycle exits during carry/flight/prone, and real boss encounter death/clear followed by exit/music replacement. Throw audio checks use `playback_requested` for exact resource/bus, both facings, one request per successful pair, silent failed/reentrant attempts and no replay across phases. The encounter suite checks four ordered starts/clears, exact 3/3/4/1 composition (ending: three Williams plus Linda), early exit/music gating during every fight, dead-player activation prevention, and physical walking from spawn through every trigger to the exit with the real boundaries and camera (enemies are removed after each wave spawns). The music suite checks the boss track actually wraps at its end as well as stage/clear routing. The existing pivot suite still checks canvas/clipping for inverted victim art but does not incorrectly require raised boots to be a planted-foot pivot.

Latest verification with Godot **4.7.2**: clean headless import, **13/13 full suites passed without diagnostics** (the runner covers every `smoke_test_*.gd`), and `git diff --check` passed. Abobo's level test uses the shared audio-server settle teardown to avoid MP3 shutdown races.

The original Abobo implementation also verified a standalone 120-tick run and byte-identical sprite regeneration (all 66 previously tracked Billy PNGs unchanged), and natively inspected reference/generated art. This follow-up changed no art. No browser/computer use, audible verification, or interactive playtest was performed; placement and audio requests are headless-tested.
