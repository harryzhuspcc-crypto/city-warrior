# Stage 2 — Industrial Yard

Run `res://levels/industrial_yard/industrial_yard.tscn` directly, or finish Stage
1 normally. The playable character is **Billy Lee**, as shown by the HUD.

## Getting here

Stage 1 still requires all its fights, including Linda and Abobo, and reaching
the exit at x=1192. It then shows its clear banner for 60 physics frames, walks
Billy right for 78 frames at 90 px/s, and fades to black over 24 frames. He
actually walks past the right screen/world edge rather than sticking against
its collision wall. No keypress is required and held attack/jump/direction
inputs cannot interrupt the cinematic. Stage 1's old post-clear restart prompt
is replaced by this automatic progression; defeat still offers restart.

The next scene fades in over 24 frames and holds a **STAGE 2 / INDUSTRIAL YARD**
title for 45 more. Billy enters at **(56,192)** with full health, normal body
collisions and fresh input/combat state. The camera starts at **(192,108)**.
The top-right HUD permanently identifies the current stage. The old level and
its actors/audio are freed; no global campaign singleton retains them.

## Map

The new native-pixel map is **1536×272** (four 384-pixel screens wide), drawn at
**(0,-56)**. Its continuous concrete apron matches the existing ground band:
world y=152..216. World walls and moving screen-edge walls use the existing
collision rules. Industrial gates, machinery, pipes and warehouse panels come
from the supplied `assets/source_sheets/new-york-20xx.png`.

This is a newly composed **flat prototype layout**, not an arcade-exact
reconstruction of the source map's stairs, pits, rooftop or river topology.
Background ladders/stairs are decorative here; no invisible climbable objects
or mismatched pit collisions are added. The original Stage 1 art is unchanged.
The source-sheet prototype-only licensing warning still applies.

Regenerate the map (requires Pillow):

```sh
python3 -m venv /tmp/stage-map
/tmp/stage-map/bin/pip install Pillow
/tmp/stage-map/bin/python tools/build_stage_two_map.py
```

The generator preserves native pixels, tiles a clear concrete apron, and
avoids the raw composite's white/green empty regions. Its output is
`assets/stages/industrial_yard.png`.

## Encounters

| Arena | Trigger x | Enemies |
| --- | ---: | --- |
| Gate | 160 | 3 Williams |
| Loading bay | 640 | Williams, Linda, Williams |
| Warehouse | 1088 | Williams, Linda, Williams, Linda |
| Boss | 1400 | 1 Abobo |

Encounters are sequential prerequisites with the existing 45-frame spawn
spacing. They lock the forward-scrolling camera, target Billy, and require
every enemy to leave before clearing. Abobo appears at **(1224,184)** inside
the final clamped view. Exit **(1496,184)** only clears after all four arenas.
Enemy behavior/stats are reused, not copied or secretly increased.

`06_industrial_area.mp3` loops on Music at -6 dB. Boss activation replaces it
with `03_abobo_entrance.mp3`; the exit replaces gameplay music with the existing
mission-complete cue. Stage 2 is the current final stage: it shows **STAGE 2
CLEAR**, then offers J to replay Stage 2. Defeat/J also reloads Stage 2, never
the project's Stage 1 main scene. No nonexistent Stage 3 is requested.

## Implementation / verification

`PrototypeAlley` is reused as the common level orchestrator (despite its
original prototype name). The optional `StageTransition` child owns cutscene
control, the existing movement/visual workers, fullscreen CanvasLayer fade,
and a deferred scene change. Its optional next-stage path is populated only
on Stage 1. Intro cleanup restores saved collisions, vulnerability and input;
the normal level clear/restart path remains available when there is no next
stage. Scene-change failures return to a visible restart prompt.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_stage_two.gd
python3 tools/run_smoke_tests.py
```

The Stage 2 suite checks intro/overlay/control restoration, art/camera/floor
alignment, music routing, every exact mixed roster, physical walking through
the real map boundaries and all triggers to the exit, early-exit/death guards,
terminal clear/replay messaging, and a real Stage 1 → Stage 2 scene replacement.
It verifies Billy visibly walks fully offscreen despite held inputs, a single
transition request frees Stage 1, fresh health/input/camera arrive in Stage 2,
and dying/restarting there reloads the industrial scene with a fresh intro.
Assets are also checked for byte-identical regeneration and no sheet matte.
No browser/desktop automation or interactive playtest was used.

Verified with Godot **4.7.2**: clean headless import, **15/15 smoke suites pass
without diagnostics**, deterministic map regeneration, and `git diff --check`.
