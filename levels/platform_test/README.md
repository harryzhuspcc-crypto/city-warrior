# Billy platform laboratory

Open `platform_test.tscn` in Godot and use **Run Current Scene (F6)**, or run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/rossz/workspace/games/city-warrior res://levels/platform_test/platform_test.tscn
```

This scene uses the normal Billy player and shared terrain motor, with no stage controller, encounters, or progression. Three stacked tiers rise by 32 pixels each; every tier has an amber, 20-pixel-high solid block. Walking into a raised face stops Billy; jumping high enough clears it. Walking fully beyond a platform's footprint starts a gravity-driven fall to the lower tier or ground underneath. Front and outer side edges are open; a solid rear boundary blocks walking and jumping above the platforms; the surrounding ground keeps the test safe.

- WASD / arrows: move across the floor's two axes.
- K: jump.
- J / L: punch / kick.
- R: restart the fight with full health and fresh enemies.
- 0: place Billy on the ground.
- 1 / 2 / 3: place Billy on the corresponding tier.

The HUD shows absolute foot elevation and airborne/grounded state. Support uses Billy's existing rectangular foot collider, so falling begins when that footprint clears the edge.

Headless movement regression:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke_test_platform_lab.gd
```

Four active sparring enemies spawn by default: Williams on the ground and tiers 1 and 3, and Linda on tier 2. They use normal combat AI and the same terrain support/fall rules. Disable `spawn_enemies` on the scene root for movement-only testing.

Scenery, camera, HUD, Billy, and enemy instances are saved in the scene and visible in the 2D editor. Enemy positions are authored at their visible feet; `terrain_height` converts those positions to ground-depth coordinates at runtime. Terrain support polygons are stored in `platform_test_layout.tres`; edit that resource alongside scenery when changing platform geometry.

Enemies in this lab enable `can_follow_platforms`: they route through reachable steps, jump up to 40 pixels per rise, steer while airborne, and follow Billy back down. Normal combat resumes on arrival. This opt-in behavior currently plans over static support polygons; existing stages retain their previous enemy behavior. The source sheets have no jump animation, so deliberate jumps hold a walking pose in the air.
