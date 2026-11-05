# Stage 2 — Original Industrial Yard Picture

Run `res://levels/industrial_yard/industrial_yard.tscn` directly, or finish
Stage 1. Billy still walks off Stage 1, fades out, and enters Stage 2 at
**(56,192)** with full health and a fresh camera/input state.

## Artwork is unchanged

`assets/stages/industrial_yard.png` is a **1056×576**, native-resolution,
RGBA-exact crop of `assets/source_sheets/new-york-20xx.png` at **(1232,0)**.
It is displayed at **(0,-264)** with nearest filtering and no scaling.
This includes the lower yard and the entire front ladder, not just the roof.

There are **no** rearranged/tiled panels, raised replacement streets, newly
painted shafts, added signs, or conveyor overlays. The original transparent
regions remain transparent. The one small blue conveyor stays where it was
drawn. Collision metadata is separate and never paints into the picture.
The third-party source remains prototype-only, not cleared for distribution.

The **image/layout** matches the source; collision heights, jump tuning and
combat are this project's implementation, not original arcade game code.

## Physical route

- **WASD / arrows:** move across each actual platform top, including depth.
- **K:** jump right onto the concrete block from the ordinary starting lane,
  then jump the dark gap to the girder pile. From around **(500,192)**,
  jump right onto the warehouse roof. The red steps remain usable, but the
  old mandatory backwards zigzag is no longer required.
- The visible blue belt carries fighters right at **24 px/s**, only while
  supported on its top. It does not move airborne fighters. No drawn belt
  animation covers or replaces the source artwork.
- **Up** at the rear ladder climbs to the original upper awning; **Down**
  returns. This ladder closes during fights to prevent camping out of reach.
- **Down** at the front roof ladder descends to the lower yard; **Up** climbs
  back onto the fighting roof. This essential connection stays usable during
  fights. Reaching its top hands control back to normal combat immediately.
- **J/L:** existing punch/kick; airborne attacks remain available.
- After Abobo, approach the **green door** at **(800,176)**. The HUD identifies
  this exit. Being far right, airborne, or on the awning does not clear it.

Billy's Stage-2-only jump takeoff is **420 px/s** at the existing **600 px/s²**
gravity (a discrete apex of about **143 px**, previously only **105 px**).
This comfortably clears the **128 px** girder-to-roof rise. Stages 1 and 3
keep their previous jump tuning; Stage 3 now owns a separate stats resource.
Descending jumps can catch the concrete top within **32 px** of depth and
the girder/roof within **16 px**. The actor is moved onto the real traced
top, not left standing on invisible enlarged support. There is no horizontal
snap, no filling of gaps, no magnetism onto the narrow tower tops, and no
snapping through solid bodies. Ordinary walking still uses exact foot support.
Sixteen-pixel step-ups are automatic; tall girder faces require a jump.
A **K** pressed up to **8 frames** after walking off an edge still jumps from
that edge, so a slightly late press at the red steps reaches the olive roof.
Unsupported feet fall. A missed jump costs **20 HP**, recovers to nearby
supported ground and grants **45 frames** of protection; lethal falls use
the existing defeat/replay flow. The lower yard is supported ground, not a pit.
How far up (back) fighters can walk follows the drawn floor, so it varies:
the lower yard stops at the warehouse wall, but its narrow side alley
(x≈994–1020, between the wall and the brick pillar) runs about **80 px**
further back. The opening street also reaches a little higher beside the lamp.
Only the **opening gap** (picture x ≤ **420**, `fall_zone_max_x` in the layout)
is a real pit. Past it, every red girder, step, tower and roof edge holds
fighters in like a wall: walking only steps down 18 px or less, and jumps
can't carry anyone over empty space. Bigger drops need a jump onto a lower
top, or the ladders. The pit recovery remains as a safety net.

## Collision implementation

`assets/stages/industrial_layout.json` traces **13 actual surface polygons**
in native picture coordinates: ground, concrete block, girder pile, four lower
steps, two tower tops, loading roof, blue conveyor, awning, and lower yard.
It also traces crate footprints. No vertical girder faces are treated as
walkable surfaces.

`BeltTerrainMap` builds real **Area2D/CollisionPolygon2D** support shapes on
layer 11 and **StaticBody2D/CollisionPolygon2D** crate obstacles on layer 10.
The solid rear factory wall uses layer 13, including during rooftop jumps.
Support selection tests both x and depth against these same traced outlines;
it is no longer an x-only height strip. Back edges stop movement into walls;
front/side edges and the slanted roof outline permit genuine falls.

Opening-route correction: the concrete block's right outline reaches **x=368**
at its front corner (the former trace omitted a 16 px strip). The road and the
rubble in front of the block are ground right up to the block's base, and its
top face starts at **x=272** like the art, so jumping from against its front lands
on top instead of dropping through a sliver of pit. Actor support
uses the actual **BodyCollision** footprint, not just the root point: positive
foot/platform overlap keeps Billy standing at seams and slanted edges. Point
queries remain strict for authoring and safe-checkpoint margins. Cached polygon
bounds reject distant platforms before overlap tests; real gaps stay empty.
The opening road's lower crop edge has a solid world-boundary polygon so
walking past its grates cannot send Billy into the blank area below the map.

`BeltTerrainMotor` separates actor depth from elevation, sweeps movement against
tall faces, resolves landings across gravity ticks, handles belt velocity and
safe recovery, and filters crate collisions by floor. Ladder heights include
the supporting roof. The camera follows elevation and the lower yard without
bobbing with jumps. Existing height-aware combat and raised Abobo throws remain.
Stages 2 and 3 share these adapters with separate layouts; Stage 1 behavior
is unchanged.

Regenerate the unmodified crop and its export-safe manifest (requires Pillow):

```sh
python3 tools/build_stage_two_map.py
```

The generator writes `industrial_yard.png` and `industrial_layout.tres`.
The `.tres` dependency ensures terrain metadata survives selected-resource
exports; JSON is only the authoring source.

## Encounters and progression

| Arena | Trigger x | Enemies | Spawn floor |
| --- | ---: | --- | ---: |
| Gate | 160 | 3 Williams | 0 |
| Girders | 464 | Williams, Linda, Williams | 80 |
| Warehouse | 720 | Williams, Linda, Williams, Linda | 208 |
| Boss | 880 | 1 Abobo at (704,208) | 208 |

Sequential prerequisites, camera locks and 45-frame spawn spacing remain.
Spawns are on their real fight decks. Jumping over a trigger arms it on landing.
All four fights and safely reaching the door are required to clear.

`06_industrial_area.mp3` loops on Music at -6 dB; boss activation switches to
`03_abobo_entrance.mp3`, and clear uses the mission-complete cue. Clearing the
green door starts the existing walk-off/fade into `levels/woods/woods.tscn`
(Stage 3). Defeat still offers **J** to replay Stage 2.

## Verification

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_stage_two.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_industrial_terrain.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_industrial_opening.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_industrial_accessibility.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_industrial_no_falls.gd
python3 tools/run_smoke_tests.py
git diff --check
```

Tests compare **every raw RGBA pixel** with the original crop, verify actual
physics-server support shapes and crate blocking, native belt carry/airborne
exclusion, both ladders in both directions, front-ladder combat handoff, falling,
recovery and defeat. The stage suite traverses the block/gap/steps/roof using
real buffered jumps and movement, clears every exact roster, and reaches the
green door without fall damage. It also checks intro, audio, early-exit guards,
replay, and actual Stage 1 → Stage 2 replacement/restart. No browser/desktop
automation or interactive playtest is used.

The opening regression covers the previously unsupported concrete strip,
diagonal edge walking, partial foot contact on girders, a buffered jump from
the block's real edge, decorative street grates and the opening road boundary.
It also verifies that stepping into the actual gap still starts a fall.

The accessibility regression uses ordinary **Right + K**, from three initial
depths and three roof takeoff positions. It checks concrete/girder landings,
the direct forward roof route, no fall damage, and an unchanged real pit.
