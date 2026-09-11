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
