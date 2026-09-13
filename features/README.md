# Feature layout

Gameplay is organized by feature rather than file type:

- `audio` — actor SFX/Voice playback and one-at-a-time looping stage/boss music.
- `actors/common` — reusable actor data and worker components.
- `actors/player` — the player scene, input adapter, state machine, and visuals.
- `actors/enemies/common` — reusable enemy AI, state machine, and visuals workers.
- `actors/enemies/williams` — the first enemy scene, stats, and orchestrator.
- `actors/enemies/abobo` — the boss scene and stats; composes the shared enemy
  fighter and paired throw worker with a once-per-confirmed-throw Voice cue.
- `camera` — the belt-scroll camera: forward-only follow, encounter lock, screen-edge walls.
- `combat` — shared attack resources.
- `encounters` — sequential encounter controllers that spawn enemies, lock the
  camera, and report each clear. The prototype stage chains opening, middle,
  ending (three Williams each), then boss (one Abobo) through explicit prerequisites.
  Boss activation replaces the stage BGM; all four clears plus exit replace it
  with mission-complete music. Placement/audio details: `actors/enemies/abobo/README.md`.
- `hud` — stateless UI projections fed by the level through methods.
- `level_objects/ladder` — passive climbable ladder areas queried by the player's climb component.
- `level_objects/ledge` — the elevated surfaces those ladders lead to: a height above the ground plane plus the span of stage x it covers.

Child components emit past-tense signals upward. Actor roots issue commands to components through typed methods.
