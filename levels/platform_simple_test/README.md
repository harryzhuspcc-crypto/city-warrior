# Platform simple test: learn to draw terrain

Open `res://levels/platform_simple_test/platform-simple-test.tscn`.
This is an independent, enemy-free practice scene. Billy starts on Level1.
The two platforms have absolute heights **32** and **64**. They share the
same depth lane, so moving right and jumping connects them.

## 1. Run the unchanged example

Use the editor's **Run Current Scene** button (F6; some Mac keyboards need
Fn+F6). Do not use Run Project, which starts the stage selector.

- WASD/arrows: move; K: jump. Keep the direction held until landing.
- **1**: reset onto the lower platform; **2**: reset onto the upper platform.
- **0**: reset onto the ground; **R**: reload this scene.
- Walk right toward the upper platform: its face stops you. Tap K while
  continuing right to land on top.
- Walk off a front or outside side edge: Billy falls to a lower surface.
- Walk or jump upward into a gold rear edge: the wall stops you.

## 2. Find the editable boundary

Stop the game and switch to Godot's **2D** workspace. In the **Local** scene tree:

```
PlatformSimpleTest
  Platforms
    Ground
    Level2
    Level1       <- select this Polygon2D
  Terrain       <- generates runtime terrain; do not edit its generated children
  Camera2D
  Actors
    Player
  HUD
```

Select **Platforms / Level1**. Its four polygon vertices are the visible
TOP boundary and the actual source of gameplay terrain. There is no separate
JSON or layout resource to update. Keep Ground as the first background node;
the upper platform is drawn before the lower one so their faces overlap correctly.

## 3. Drag one corner

With Level1 selected, use the polygon edit tool in the toolbar above the 2D
viewport. Drag a vertex handle, rather than dragging the whole node.
For a first exercise, drag the **front-left corner** slightly downwards to
make the platform deeper. Keep the shape convex and do not cross edges.
Use editor grid snapping for small, repeatable changes.

Save the scene, then **stop and run the current scene again**. Press 1 to
reset Billy onto it, and walk toward the changed edge. The new outline now
controls where he falls. Front/side shading and the rear wall preview update
from the same vertices. Runtime terrain is built on scene startup, so editing
while the game runs does not rebuild that already-running instance.

## 4. Draw a replacement outline

Select the platform's native Polygon property in the Inspector to inspect
its coordinates. Use Godot's polygon creation/edit tools to replace or extend
its outline. For this exercise keep a four-corner shape, in this order:

1. Rear-left.
2. Rear-right.
3. Front-right.
4. Front-left, then close back to the first point.

This is clockwise as seen on screen. The first segment, from vertex 0 to
vertex 1, is the rear wall. Use **Rear Edge** in the Inspector if you change
which segment should be protected. The gold preview shows the selected edge.
Use simple convex shapes for this tutorial; the reset shortcut places Billy
at the average of the vertices, which need not be inside a concave shape.

## 5. Set platform height and wall behavior

The script fields appear in the platform's Inspector:

| Property | Meaning |
| --- | --- |
| Height | Absolute elevation above ground; Level1 = 32, Level2 = 64 |
| Solid | The raised platform face blocks actors below its top |
| Fall From Edges | Unsupported front/side departures fall downward |
| Rear Wall | Generates an always-solid wall along the selected edge |
| Rear Edge | Zero-based segment index; 0 is vertex 0 → vertex 1 |
| Show Depth Footprint | Editor-only preview of the underlying movement-plane footprint |

The rear wall is a vertical boundary, not a jumpable low rail. It remains
solid while Billy is airborne. Toggle **Rear Wall** off, save, and restart to
experiment with an open rear edge. Leave **Fall From Edges** on for these
platforms; switching it off enables the shared terrain motor's edge protection.

Height is different from Godot collision layers and from Z Index. Do not
assign one collision layer per elevation. The existing terrain motor decides
when each face blocks Billy based on his current elevation.

## 6. Understand depth before changing height

The polygon is drawn at the character's visible feet. Gameplay also needs
an underlying movement-plane footprint:

```
footprint_y = visible_top_y + Height
```

Enable **Show Depth Footprint** on both levels. Faint outlines show those
footprints, with dashed lines connecting them to their visible tops. The two
platforms' faint side edges should meet for an adjacent rightward jump.

Changing Height alone leaves your drawn top in place and changes its depth
footprint. To raise a platform by 8 while preserving its existing footprint:

1. Increase Height by 8.
2. Move that platform node UP by 8 pixels (subtract 8 from Position Y).
3. Check the faint outline still meets its neighbor.
4. Save and restart to test.

Keep node Rotation at 0 and Scale at (1, 1). Change size by moving vertices.
Keep height differences modest: this example's 32-pixel step is comfortably
within Billy's normal jump. Arbitrarily tall steps are not automatically reachable.

## 7. Inspect actual runtime physics

**Debug → Visible Collision Shapes** overlays Godot's physics shapes when
running from the editor. Their movement-plane outlines may sit below the
visible tops because elevation is projected separately. The editor's faint
footprint preview explains that offset. Gold is a rear wall; blue is the top
outline; no blue outline alone means an impassable edge.

Always make lasting edits in the **Local** tree. Changes to generated nodes
in the **Remote** tree are temporary and are discarded on restart.

## Implementation and validation

- `editable_platform.gd`: native Polygon2D editing, height settings, editor preview.
- `editor_terrain.gd`: reads those scene polygons into the existing terrain motor.
- `platform_simple_test.gd`: player setup, reset shortcuts, height status.
- No changes to industrial terrain or to the older platform lab are required.

Regression test:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke_test_platform_simple.gd
```

It checks the solid step, rightward jump, both rear walls while walking and
jumping, front/side falls, and saved/reloaded polygon and height edits.

Godot references:
- [Collision shapes](https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_2d.html)
- [Polygon2D](https://docs.godotengine.org/en/stable/classes/class_polygon2d.html)
