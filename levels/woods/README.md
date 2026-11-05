# Stage 3 — Woods and Cliff Entrance

Run `res://levels/woods/woods.tscn` directly, or clear Stage 2's green door.
Stage 2 now transitions here using the existing clear/walk-off/fade sequence.
Billy starts at **(56,288)**, on the woods floor (elevation **96**), with full
health, a fresh camera, and the Stage 3 title card.

## Original artwork, new collision shapes

`assets/stages/woods.png` is an unchanged **2928×496** RGBA crop at
**(2288,240)** of `assets/source_sheets/new-york-20xx.png`. It includes the
woods, broken wooden bridge, cliff approach, lower steel deck, and headquarters
entrance. It is displayed at **(0,-112)** with nearest filtering, no scaling,
and no painted/tiled replacement floors. Source transparency stays unchanged.
These third-party prototype assets are not cleared for distribution.

`assets/stages/woods_layout.json` is the separate collision authoring source.
Its `.tres` runtime manifest is explicitly referenced by this scene, so it
survives selected-resource exports. `BeltTerrainMap` now accepts a layout
resource; Stage 2 still defaults to its existing industrial layout.

The layout builds eight **Area2D / CollisionPolygon2D** support shapes on
layer 11 and two **StaticBody2D / CollisionPolygon2D** world-edge shapes on
layer 1. Shapes trace both banks, each surviving half of the wooden bridge,
the slanted cliff approach, lower steel deck, upper terrace, and small rock
ledge. Each has its own assigned polygon; no collision node is scaled.
The gap between the broken planks and the river below have **no hidden floor**.
The dark shallow woodland depressions are decorative, not extra pits.

The shared terrain motor uses those same outlines and fighters' actual foot
shapes for support, steps, jumps, landings and recovery. River and cliff-deck
regions allow real falls; other map edges hold fighters against the scenery.
Missing a jump costs 20 HP and returns Billy to supported ground with brief
protection. Stage 1's movement and Stage 2's collision trace are unchanged.

## Route and controls

- **WASD / arrows:** move across the bank and the narrow wooden bridge.
- **K:** jump the missing bridge planks. Stage 3 uses the existing raised
  360 px/s jump tuning, sufficient for this gap.
- Continue through the eastern woods onto the sloping rocky approach.
  Approach its right edge at depth about **304**, then jump right/down onto
  the lower steel deck (elevation **0**).
- At **(2500,304)**, hold **Up** on the visible cliff handholds to climb to
  the terrace (elevation **224**). **Down** here returns to the deck outside
  encounters. Landing releases climbing and restores normal vulnerable combat.
- **J/L:** existing punch/kick and airborne attacks remain available.
- After all encounters, approach the cliff door at **(2792,272)**. Passing its
  x-coordinate, jumping past it, or visiting it before clearing fights is not
  enough to clear the stage.

Collision heights and route behavior are this project's implementation, not
original arcade code. The camera follows supported elevation and actor depth;
it does not bob with jumps.

## Encounters and music

| Arena | Trigger x | Roster | Floor |
| --- | ---: | --- | ---: |
| Forest | 320 | 3 Williams | 96 |
| West bridge approach | 704 | Williams, Linda, Williams | 96 |
| East forest | 1472 | Linda, Williams, Linda, Williams | 96 |
| Cliff door | 2608 | Abobo | 224 |

The four waves keep sequential prerequisites, camera locks and 45-frame spawn
spacing. Markers stand on supported ground. Ladders close during encounters
to prevent camping. `07_woods.mp3` loops on Music at -6 dB; Abobo switches to
the existing boss track; clear uses the mission-complete cue. Stage 3 is
terminal for now: clear or defeat offers **J** to replay this stage.

## Regeneration and headless checks

```sh
uv run --with pillow python tools/build_stage_three_map.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_stage_three.gd
python3 tools/run_smoke_tests.py
git diff --check
```

The Stage 3 suite checks exact source pixels, physics-server support and the
bridge gap, real movement/jumps across the map, cliff climbing in both
directions, all four encounter spawns, door gating, audio, replay, and actual
Stage 2 → Stage 3 scene replacement. No browser/desktop automation is used.
