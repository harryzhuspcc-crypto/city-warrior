# Feature layout

Gameplay is organized by feature rather than file type:

- `actors/common` — reusable actor data and worker components.
- `actors/player` — the player scene, input adapter, state machine, and visuals.
- `actors/enemies` — enemy-specific scenes and behavior.
- `combat` — future shared combat coordination.
- `encounters` — future wave and camera-lock orchestration.
- `hud` — future stateless UI projections.

Child components emit past-tense signals upward. Actor roots issue commands to components through typed methods.

