# Feature layout

Gameplay is organized by feature rather than file type:

- `audio` — actor SFX/Voice playback and one-at-a-time looping stage/boss music.
- `actors/common` — reusable actor data and worker components.
- `actors/player` — the player scene, input adapter, state machine, and visuals.
- `actors/enemies/common` — reusable enemy AI, state machine, and visuals workers.
- `actors/enemies/williams` — the first enemy scene, stats, and orchestrator.
- `actors/enemies/abobo` — the boss scene and stats; composes the shared enemy
  fighter and paired throw worker with a once-per-confirmed-throw Voice cue.
- `actors/enemies/linda` — atlas-backed enemy with close punches, longer-range
  whip attacks and Linda-specific voice; joins the ending Williams wave.
- `camera` — the belt-scroll camera: forward-only follow, encounter lock, screen-edge walls.
- `combat` — shared attack resources.
- `encounters` — sequential encounter controllers that spawn enemies, lock the
  camera, and report each clear. The prototype stage chains opening, middle,
  ending, then boss through explicit prerequisites. Opening/middle each have
  three Williams; ending adds one Linda to three Williams; boss has one Abobo.
  Boss activation replaces the stage BGM; all four clears plus exit replace it
  with mission-complete music. Placement/audio details: `actors/enemies/abobo/README.md`.
- `hud` — stateless UI projections fed by the level through methods.
- `stage_flow` — Billy's clear-banner/walk-off/fade transition from Stage 1 to
  Stage 2, plus the next stage's title/fade-in and input restoration.
- `level_objects/ladder` — passive climbable ladder areas queried by the player's climb component.
- `level_objects/ledge` — the elevated surfaces those ladders lead to: a height above the ground plane plus the span of stage x it covers.

Child components emit past-tense signals upward. Actor roots issue commands to components through typed methods.

Playable levels: `levels/prototype_alley/prototype_alley.tscn` (Stage 1) and
`levels/industrial_yard/industrial_yard.tscn` (Stage 2). Stage 1 now advances
automatically after its exit; Stage 2 currently ends with a replay prompt.
Map, encounter and transition details: `levels/industrial_yard/README.md`.
