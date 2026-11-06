# Stage 4 — Enemy Headquarters

Run `levels/headquarters/headquarters.tscn` directly, or clear the cliff-door
encounter in Stage 3. Stage 4 is the campaign's terminal stage.

## Entrance walls

One 24×24 stone in each of the three carved panels at x=240, 352, and 464
thrusts into the entrance lane. The surrounding panel never moves.
Their clocks start only after the intro releases Billy's controls. Each wall
repeats exactly every **240 physics frames (4 seconds at 60 Hz)**:

| Cycle frames | Behaviour |
| --- | --- |
| 0–122 | Fully retracted; green indicator; safe crossing |
| 123–167 | Amber floor outline/arrows and audible warning; still safe |
| 168–179 | Rapid thrust to 64 px extension |
| 180–215 | Extended hold |
| 216–239 | Retraction; contact remains lethal until fully clear |

Walls two and three have fixed 60- and 120-frame offsets. There is no random
timing or proximity trigger. Wait between panels, then cross when the face
has retracted. Follow the narrowing floor upward after the last panel.

Each stone face comes directly from the bottom row of the stage picture.
The fixed socket, perspective growth and diagonal foreshortening, textured
top, shaded side, cast shadow and impact dust make a projecting 3D cuboid,
not a downward-sliding wall. A fast eased thrust and slower hydraulic return
share the same deterministic physics clock. Visual extension, Y-sort depth,
and the narrow trapezoidal lethal floor footprint use the same projection;
adjacent stationary masonry does not have an invisible panel-wide hitbox.
Swept foot rectangles catch movement into an extended face. Contact kills
immediately at any health, including during combat invulnerability or a
jump. Intro/outro, defeat, and terminal completion stop the hazard clocks;
retry restores their original deterministic phases.

## Finale

Two sequential mixed-enemy arenas lead to Willy in the dragon chamber.
Willy uses his existing arcade sprite sheet, 240 HP, close kicks, and a
30-frame gun windup. Visible gun rounds deal 18 HP and can be avoided by
changing lanes or jumping. Clearing every arena unlocks the rescue at the
dragon door, plays the ending theme, and offers final-stage replay.

The original `final-mission.png` is packaged unchanged. Five separate floor
polygons trace the entrance, narrow statue walkway, shallow steps, brick
hall, and dragon chamber. The pictured spikes are not hidden floors.

## Rebuild and verify

```sh
uv run --with pillow python tools/build_stage_four_assets.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_stage_four.gd
python3 tools/run_smoke_tests.py
python3 tools/build_web.py
```

The Stage 4 suite exercises original-pixel preservation, drawn-floor spawn
support, the full route with real movement and active traps, repeatable
warning/thrust/retraction timing, instant death, gunfire/jump dodging, the
actual Stage 3 → 4 scene replacement, rescue, and current-stage restart.
The Web builder also boots Stage 4 from the exported PCK.
