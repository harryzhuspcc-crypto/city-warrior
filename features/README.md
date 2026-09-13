# Feature layout

Gameplay is organized by feature rather than file type:

- `audio` — the stage's background music.
- `actors/common` — reusable actor data and worker components.
- `actors/player` — the player scene, input adapter, state machine, and visuals.
- `actors/enemies/common` — reusable enemy AI, state machine, and visuals workers.
- `actors/enemies/williams` — the first enemy scene, stats, and orchestrator.
- `camera` — the belt-scroll camera: forward-only follow, encounter lock, screen-edge walls.
- `combat` — shared attack resources.
- `encounters` — sequential encounter controllers that spawn enemies, lock the
  camera, and report each clear. The prototype stage chains opening, middle,
  and ending arenas through explicit prerequisites.
- `hud` — stateless UI projections fed by the level through methods.
- `level_objects/ladder` — passive climbable ladder areas queried by the player's climb component.
- `level_objects/ledge` — the elevated surfaces those ladders lead to: a height above the ground plane plus the span of stage x it covers.

Child components emit past-tense signals upward. Actor roots issue commands to components through typed methods.
