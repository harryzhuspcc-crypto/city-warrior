# Industrial yard

Run `res://levels/industrial_yard/industrial_yard.tscn` directly or enter from
Stage 1. A single locked `Background` sprite displays the original industrial
image. The game hides the collision outlines at startup. Press **B** to show
or hide them during play without affecting the artwork or physics.

## Geometry and movement

Open `industrial_blocks.tscn` in the 2D editor to edit the terrain over the
fixed picture. The main stage instances this scene and reads its polygons at
startup. The layout resource still supplies map-wide settings such as fall
zones and the image offset.

- **Surfaces** (light blue): trace the visible tops where Billy can stand. Select a
  polygon under `CollisionOutlines/Surfaces` and edit its vertices. `Height` is
  the absolute floor elevation. `Solid` blocks approach below that height,
  and `Fall From Edges` allows falling from exposed edges.
- **Blockers** (orange): draw wall footprints under
  `CollisionOutlines/Blockers`. `World Boundary` blocks at any height. A
  `Solid Wall` blocks within its base height range, as on the loading deck.

For a new surface, duplicate a node under Surfaces or attach
`../platform_simple_test/editable_platform.gd` to a `Polygon2D`. Use native
vertices and `Height`; set fill alpha to zero and `Draw Side Faces` off over
this fixed artwork. The simple scene keeps its filled side-face preview.
`Rear Wall` and `Rear Edge` select the gold boundary; both adapters use the
same method to project its 12 px outward blocker. Industrial platforms use
`Rear Wall On Level Only`: per-actor collision exceptions enable each wall
only at its authored base height, retaining that floor during a jump. A
lower floor's wall must not block an actor standing on a higher floor.
Independent Blockers still use `industrial_terrain_outline.gd`. Save `industrial_blocks.tscn` and restart `industrial_yard.tscn` to
play the edits. For a surface the footprint is projected down by its `Height`,
so neighboring visible tops at different heights can share a depth boundary.

For a quick movement test, run `industrial_blocks_test.tscn` as the current
scene. It uses the same saved outlines and starts Billy on the street;
the camera follows him so the spawn stays visible. Use WASD or the arrow keys to move, K to jump, B to toggle the outlines,
and R to restart at the spawn point.

| Surface | Elevation | Behavior |
| --- | ---: | --- |
| Opening street / lower yard | 0 | Ground floors; original map limits |
| Concrete plinth | 48 | Solid face; jump from street; front/side departures fall, rear wall protects back |
| Level 1: girder pile | 80 | Exposed edges allow falls |
| Level 2: three small steel plates | 104 | Connected left and front sections, all on the same floor |
| Level 3: steel tower | 152 | One continuous top, 48 px above the lower steel platform |
| Level 4: loading deck | 192 | Front/side falls; rear factory wall blocks movement |
| Conveyor | 208 | Solid raised face; carries supported actors at 24 px/s |
| Left crate tiers | 240, 264, 288 | Three solid volumes with individual top surfaces |
| Right crate tiers | 216, 240, 264 | Three solid volumes with individual top surfaces |
| Upper awning | 320 | Ladder access, walk/jump control, front/side drops, rear protection |

Raised faces require a jump high enough to clear them. A foot must retain
positive overlap with the top to remain supported. Leaving a fallable edge
starts gravity; land on the next real surface underneath or enter the existing
pit/recovery flow if there is no floor. Landing assistance cannot pull a drop
back onto its takeoff surface. No floors are added across the opening gap.

The roof's left edge can drop onto steel; the front above the lower yard drops
to that yard. Other unsupported roof edges remain genuine falls. Walk in front
of the crate stacks and conveyor or jump onto their tops. The awning ladder
hands Billy to normal terrain movement instead of holding him on an invisible
one-dimensional ledge. Down near either ladder starts descent to its base.

WASD/arrows move, K jumps, J/L attack. Enemy encounters default to enabled in the main industrial stage, including
entry from the stage picker and Stage 1. The original four sequential waves
remain intact. Use `industrial_blocks_test.tscn` for enemy-free platform testing;
the main scene root also exposes `enemy_encounters_enabled` for explicit debugging.
Music, camera, green-door exit and progression remain active.

## Regeneration

```sh
python3 tools/build_industrial_blocks.py
```

This seeds the editor scene if it is missing. It keeps existing saved edits.
To re-extract the original image crop and refresh the map-wide layout settings:

```sh
python3 tools/build_stage_two_map.py
```

The picture uses native coordinates at offset `(0, -264)`. Edit terrain
polygons in Godot. The image extraction command keeps those edits.

## Verification

Headless tests include `smoke_test_industrial_blocks.gd` (outline visibility, edited support,
crate clearance and landing, deck/awning drops and rear walls),
`smoke_test_industrial_terrain.gd` (original pixels, physics shapes, conveyor,
both ladders, pit recovery), `smoke_test_industrial_accessibility.gd` and
`smoke_test_industrial_opening.gd` (real jump route),
`smoke_test_industrial_no_falls.gd` (rear-wall protection),
`smoke_test_industrial_platform_edges.gd` (steel drops), and
`smoke_test_stage_two.gd` (complete stage progression).

The two rows of beams on each large steel top are a single flat surface, not
separate height bands. Their full drawn depth remains walkable and supports
ordinary jumps across the platform width without increasing jump strength.

Height correction: the small plates are 24 px above the 80 girder, not
48 px. StepLanding's front vertices moved from `(544,320)/(464,320)` to
`(536,312)/(456,312)` to follow the pictured top instead of its side face.
Step1, Step2 and StepLanding share height 104; their shared edges have no
rear walls. Walk diagonally around the tower along the pictured connected
strip, then horizontally across the front pieces; the reverse route also
remains grounded without jumping.

The tower is 152 and the deck is 192. Their projected adjoining diagonals
would overlap by 8 px after correcting heights, so the deck's left vertices
are inset from x=560/640 to x=568/648. Its projected left edge starts at
`(568,136)`, on the same line as the tower's right edge `(560,128)` to
`(592,160)`. No global polygon inflation bridges unrelated gaps.
The roof's front projects to ground y=216, matching picture y=480; ladders,
crate/conveyor floors, exit, encounter spawn markers and handoffs moved with
that correction. The independent factory wall remains the only deck rear
wall; it is not duplicated by an automatic one.

The tower allows up to 16 pixels of depth assistance only while descending
through its actual top height. This catches near-front-corner jumps without
raising jump strength or allowing movement through taller faces.

Keyboard regression: `smoke_test_industrial_keyboard_jump.gd` sends real D/Right
and K key events through the 104 → 152 → 192 route, including a preceding
direction tap and either key order. K overrides a pending double-tap head
attack within the three-frame chord window. Intentional double-tap attacks
still work after that window.

## Regression rules from this repair

- Separate visible top coordinates, absolute height, and the projected ground
  footprint (`picture_y + image_offset_y + height`). Screen overlap does not
  imply that two floors share depth or elevation.
- Diagnose a raised solid face separately from a rear boundary. A valid
  24 px rise still needs K; never fix it by making every rise walkable.
- Keep equal-height connected plates traversable in both directions,
  including diagonal seams. Check support on every frame, not only endpoints.
- Test the real 80 → jump → 104 landing → W route: feet must cross the lower
  girder's gold screen line and stop only at the landing's own rear edge.
  Test jumping against that edge too, and lower-floor collision exceptions.
- Keep world boundaries independent; don't turn every wall into a platform
  or activate all stacked rear walls with one global collision-layer switch.
- Preserve background pixels and existing editor comments. Reuse the top
  polygon for previews and runtime geometry; don't paint a second opaque
  side over the fixed background.
- Recheck the full 80 → 104 → 152 → 192 route, front drops, ladders and stage
  exit after height edits. Update fixtures for saved scene changes rather
  than preserving obsolete heights or teleporting to unsupported positions.

`smoke_test_industrial_rear_edges.gd` covers the lower/upper gold-line route,
rear walking/jumping, both same-height seams in both directions, diagonal
walking, and per-floor wall exceptions. The simple scene side-drop fixture
uses its outermost Level4: the user's added Level3 correctly blocks walking
straight through it from Level2.

## Concrete corner and pit lives

ConcretePlinth has `Fall From Edges` enabled. Walking down from its right/front
corner may land on the existing rubble before leaving that rubble for the real
unsupported gap; the road/rubble polygon is not removed to create a new pit.
The industrial layout starts with three pit lives. Each completed pit fall
consumes one life, restores a supported checkpoint and briefly protects Billy;
the third uses normal defeat behavior. Both the main stage HUD and the platform
lab display the remaining lives (R restarts the lab).

Landing-depth assistance only catches a higher floor than the takeoff/support
floor. Previously ConcretePlinth had `drop_edges=false`, but its x position was
inside the map's fall zone: leaving support initiated a fall and assistance
immediately pulled Billy back to height 48. The repeated fall/land cycle looked
like flickering or blocked Down input. The guard now also handles these legacy
fall-zone departures, independently of the explicit per-platform switch.
`smoke_test_industrial_plinth_pit.gd` walks down from `(360,168)` with the switch
both enabled and disabled, checks for repeated re-landings, exactly one pit/life
loss and a stable idle recovery. Real rises still use the original jump assist.
