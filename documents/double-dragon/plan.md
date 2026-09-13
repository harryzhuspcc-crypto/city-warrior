# Double Dragon-Inspired Beat-'Em-Up Plan

## Recommended direction

Build a **belt-scrolling beat-'em-up**, not a traditional one-on-one fighting game:

- `x` = horizontal stage movement
- `y` = depth/lane movement
- Jump height = separate simulated value
- Actors sort visually by their feet's `y` position
- Camera scrolls horizontally and locks during encounters

The repository is currently an almost-empty **Godot 4.7 Compatibility** project, so start with one small playable encounter.

> The downloaded sprites and Double Dragon branding remain copyrighted. They are suitable for learning/prototyping, but replace them with original/licensed assets before publishing.

## 1. Import and prepare the artwork

`../assets/double-dragon` is outside the Godot project. Godot cannot reliably import resources outside `res://`.

```bash
mkdir -p assets/source_sheets assets/sprites assets/stages
cp ../assets/double-dragon/*.png assets/source_sheets/
```

These are irregular presentation sheets, not uniform sprite grids. They also have solid-color backgrounds—for example, `billy-lee.png` uses `#80A480`.

Recommended workflow:

1. Open a sheet in Aseprite, LibreSprite, or another pixel editor.
2. Remove the solid background using exact color selection.
3. Slice individual animation frames.
4. Align every character frame using the **feet midpoint** as the pivot.
5. Export individual transparent PNG frames by animation.

Start with only:

```text
billy/
├── idle/
├── walk/
├── punch/
├── hurt/
├── knockdown/
└── death/
```

Do not extract every pose yet. Import textures with:

- Filter: **Nearest**
- Mipmaps: **Off**
- Lossless compression
- Pixel snapping enabled

Use a small internal viewport such as `384×216`, scaled by integer multiples.

## 2. Organize by feature

```text
assets/
├── source_sheets/
├── sprites/
└── stages/

features/
├── actors/
│   ├── common/
│   │   ├── health_component.gd
│   │   ├── movement_component.gd
│   │   ├── combat_component.gd
│   │   ├── attack_data.gd
│   │   └── fighter_stats.gd
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   └── player_input.gd
│   └── enemies/
│       └── williams/
├── combat/
├── encounters/
└── hud/

levels/
└── prototype_alley/
```

Avoid a generic `scripts/` folder. Keep each scene, script, and resource with its feature.

## 3. Build the player scene

```text
Player (CharacterBody2D)
├── BodyCollision (CollisionShape2D)
├── Visuals (Node2D)
│   └── AnimatedSprite2D
├── Hurtbox (Area2D)
│   └── CollisionShape2D
├── AttackOrigin (Node2D)
│   └── Hitbox (Area2D)
│       └── CollisionShape2D
├── HealthComponent
├── MovementComponent
├── CombatComponent
├── InputComponent
└── StateMachine
```

Use a simple flat state machine initially:

```text
IDLE
MOVE
ATTACK
HITSTUN
KNOCKDOWN
DEAD
```

Responsibilities:

- `HealthComponent` owns health and exposes `take_damage()`.
- `MovementComponent` owns movement speeds and moves the body.
- `InputComponent` samples InputMap actions.
- `CombatComponent` owns attack timing and hit resolution.
- `StateMachine` only decides transitions.
- `Player` wires components together.
- `AnimatedSprite2D` is presentation only.

Use `AnimatedSprite2D` rather than `AnimationTree` initially. Pixel animations do not need blending.

## 4. Configure movement

Create these InputMap actions:

```text
move_left
move_right
move_up
move_down
attack
jump
kick
grab
pause
```

Suggested keyboard defaults:

```text
WASD / arrows  Movement
J              Attack
K              Jump
L              Kick
Unbound        Grab (reserved)
```

Read movement using actions rather than hardcoded keys:

```gdscript
var direction := Input.get_vector(
    &"move_left",
    &"move_right",
    &"move_up",
    &"move_down"
)
```

Give vertical movement a lower speed than horizontal movement:

```gdscript
velocity = Vector2(
    direction.x * horizontal_speed,
    direction.y * depth_speed
)
move_and_slide()
```

Set the actors container's `y_sort_enabled` property to `true`. Ensure each sprite's origin is at its feet.

### Jumping

Do not use world `y` as jump height—it represents depth. Maintain separate values:

```text
ground_position: Vector2
jump_height: float
jump_velocity: float
```

Keep the `CharacterBody2D` on the ground plane while moving the `Visuals` node upward by `jump_height`.

Implement jumping only after walking and combat work.

## 5. Implement frame-based combat

Represent attacks using `.tres` resources:

```text
name
startup_frames
active_frames
recovery_frames
damage
hitstun_frames
knockback
hitbox_rect
```

Example first punch:

```text
Startup:  5 frames
Active:   3 frames
Recovery: 10 frames
Damage:   10
Hitstun:  14 frames
```

Run combat at 60 physics ticks per second. Track attack progress with an integer frame counter rather than timers or `await`.

Only enable the attack hitbox during active frames. Add a set of already-hit targets so one punch cannot damage the same enemy every physics frame.

Buffer the attack input for approximately 6–8 frames so controls feel responsive.

Suggested collision layers:

| Layer | Purpose |
|---|---|
| 1 | World |
| 2 | Actor bodies |
| 3 | Player hurtboxes |
| 4 | Enemy hurtboxes |
| 5 | Player hitboxes |
| 6 | Enemy hitboxes |
| 7 | Pickups |
| 8 | Screen edges (only the player collides) |
| 9 | Ladders and other passive interactables |

Player hitboxes scan only enemy hurtboxes, and vice versa.

## 6. Create one enemy

Use Williams as the first enemy:

```text
IDLE → APPROACH → ATTACK
               ↘ HITSTUN → KNOCKDOWN → IDLE
                                      ↘ DEAD
```

Keep the first AI simple:

1. Approach until horizontally close.
2. Adjust depth until aligned with the player.
3. Stop at attack range.
4. Attack after a short cooldown.
5. Back away occasionally.

Do not add pathfinding yet. Direct steering with collision avoidance is sufficient for one alley.

### Implemented Williams loop

- Implemented: `features/actors/enemies/williams/williams.tscn` reuses the
  shared health, movement, combat, hurtbox, and hit-reaction components. Its
  frames come from `tools/extract_williams_frames.sh`, which shares the
  feet-pivot library in `tools/lib/frame_extraction.sh` with Billy.
- Implemented: `EnemyAIComponent` is a sense/decide worker that mirrors the
  player input component. It waits a reaction delay, approaches horizontally,
  sidesteps out of `body_clearance_x` before aligning depth (a pure vertical
  push wedges against the target's body), stops at `attack_range_x`, requests
  an attack once the cooldown that restarts on punch completion expires, and
  retreats for `retreat_frames` with `retreat_probability` after a completed
  punch. A retreat that hits a wall ends early. Assigning a target restarts
  the reaction delay.
- Implemented: `EnemyStateMachine` uses IDLE, APPROACH, RETREAT, ATTACK,
  HITSTUN, KNOCKDOWN, and DEAD. With `acquire_player_target` on, Williams
  keeps looking for the first node in the `player` group until one exists,
  idles without one, and idles again once the target reports `is_dead()`.
- Implemented: the shared `HitReactionComponent` resolves every confirmed
  hit for both actors. Hitstun lasts `AttackData.hitstun_frames` with a
  decaying knockback slide; knockdown happens on a lethal hit, an attack with
  `knocks_down`, a hit while airborne, or the `hits_before_knockdown`th
  consecutive hit, lasts `FighterStats.knockdown_frames`, and grants
  invulnerability until the actor gets up. Death holds the fall then the
  prone pose; a dead Williams stops blocking, lingers, emits `defeated`, and
  frees itself.
- Implemented: hurt, knockdown, and death poses are scheduled from
  `FighterStats` pose-start arrays with the same frame-driven presentation
  the attacks use.

## 7. Build the prototype level

Use only one section of `new-york-20xx.png`, not the entire 5216-pixel composite.

```text
PrototypeAlley (Node2D)
├── Background
├── WorldGeometry
│   ├── TopBoundary
│   ├── BottomBoundary
│   └── SideBoundaries
├── Actors (Node2D, Y Sort enabled)
│   ├── Player
│   └── Enemies
├── Encounters
│   ├── OpeningEncounter
│   ├── MiddleEncounter
│   └── EndingEncounter
├── Camera2D
└── HUD (CanvasLayer)
```

Separate stage art from collision. Use invisible `StaticBody2D` boundaries to define the walkable strip.

Each encounter controller should:

1. Spawn three enemies.
2. Lock camera movement.
3. Detect when all enemies have died.
4. Unlock the camera.
5. Finish the prototype when the player reaches the exit.

The prototype chains three controllers from opening to middle to ending. A
controller can arm only after its prerequisite clears, and the exit remains
closed until every enabled encounter is clear.

### Implemented prototype level

- Implemented: `tools/extract_stage_section.sh` crops the first street section
  (1232×216, sheet rows 264–480) into `assets/stages/new_york_street.png`.
  The road's last row sits on the viewport bottom, so the walkable strip runs
  from the sidewalk line (world y 152) to the road bottom (y 216); layer-1
  boundaries sit exactly on the art edges.
- Implemented: `BeltScrollCamera` follows Billy along x inside the camera
  limits, stays on the single 216 px band, never scrolls back toward the
  start, and locks/unlocks for encounters. Every move is paced at
  `catch_up_speed` (an unlock pans back to Billy instead of snapping), a
  lock never pans backwards or pushes Billy out of view, and a target
  outside the view is cut to at once. Two `StaticBody2D` screen edges are
  its children on collision layer 8; only Billy masks that layer, so he
  cannot leave the view while enemies walk in from off screen.
- Implemented: `EncounterController` activates when Billy reaches `lock_x`
  (640, so the camera is already there and no pan is needed), locks the
  camera, spawns three Williams round-robin from off-screen markers every 45
  frames with `set_target(player)`, counts each enemy down once when it
  reports `defeated` or otherwise leaves the tree, then unlocks the camera
  and emits `encounter_cleared`. Reinforcements stop once Billy is dead, and
  a disabled controller does not gate the exit.
- Implemented: `Hud` is a CanvasLayer with Billy's health bar and a message
  label. The level feeds it through methods (`health_changed` → `set_health`).
  Reaching the exit marker (x 1192) after the clear shows STAGE CLEAR; Billy's
  death shows GAME OVER after a 90-frame linger. The attack action then
  requests a restart, which reloads the level when it is the running scene.

## 8. First playable milestone

Consider the first milestone complete only when it has:

- Billy idle and walk animations
- Four-direction belt-scroller movement
- Correct feet-based depth sorting
- One punch with startup/active/recovery timing
- Williams approaching and attacking
- Health, hitstun, knockdown, and death
- Three-enemy encounter
- Camera lock/unlock
- HUD health bar
- Restart after defeat

Run `player.tscn` and the enemy scene independently with F6. Each should function without relying on a level autoload.

## 9. Expand in this order

After the vertical slice feels good:

1. Three-hit punch combo
2. Basic kick and Billy's standalone special moves
3. Grabbing and throws
4. Weapons from `objects.png`
5. More enemy archetypes
6. Enemy spawn waves
7. Breakable props
8. Local co-op
9. Additional stages
10. Original replacement artwork and branding

### Kick and deferred hit-confirmed combo requirements

Reference images are stored under `documents/double-dragon/references/`.

- Implemented: the L-bound basic two-pose kick shown in `basic-kick.png` uses
  chamber and high side-kick extension poses.
- Implemented: grounded J+K uses the two-pose rear elbow in `elbow.png` and
  damages only behind Billy.
- Implemented: two rapid presses of the same horizontal direction use the
  directional head attack in `head-attack-directional.png`: pose 1 during
  startup, pose 2 while attacking, then pose 1 again during recovery. Right,
  Right uses the authored rightward art and ends facing right; Left, Left uses
  the mirrored counterpart and ends facing left.
- Implemented: grounded L+K launches the five-pose rear attack in
  `back-kick.png`; it damages behind Billy and reverses his facing only after
  natural completion at landing. While airborne it holds the extended rear
  kick shown in `back-kick-hold.png` with its deduplicated hitbox active. Its
  low hop reaches exactly 12.75 px, one quarter of the normal 51 px jump.
- Implemented: L while already airborne uses the five-pose jump kick in
  `jump-kick.png`, preserving the normal 51 px jump arc and belt-plane air
  movement. It holds the forward extension shown in `jump-kick-hold.png` and
  remains active until landing.
- Grounded J/K/L singles wait through a three-physics-frame chord window.
  Same-direction double taps use an inclusive 12-physics-frame window.
- Implemented: the three-hit punch sequence of `three-hit-punch.png`. J opens
  with Billy's basic punch, a connected punch earns the cross (the sheet's
  other-arm punch), and a connected cross earns the rising uppercut the
  reference shows. The uppercut knocks its target down.
- Implemented: the three-hit kick sequence of `three-hit-kick.png`. The sheet
  authors one basic kick, so L opens twice with it; the third connected kick is
  the five-pose turning finisher, which also knocks down. Its rear poses are a
  spin through, not a turn to face the other way, so Billy keeps his facing.
- Implemented: progression is driven by confirmed hits. `AttackChainComponent`
  advances a chain only when its own step both ran to the end and connected, so
  a whiff, an interruption, a different move, or waiting out
  `FighterStats.chain_window_frames` all send the next press back to the
  opener. Combat itself knows nothing about chains: it reports its hits and its
  finishes, and the chain component decides what they mean.
- Implemented: every step after an opener carries a short forward lunge
  (`AttackData.movement_speed` over its startup). A landed hit knocks the
  target back about 10 px for a punch and 16 px for a kick, so a chain whose
  later steps stood still could never reach the enemy its own opener pushed
  away.

### Ladder climbing

- Implemented: Billy climbs the left ladder of the SCOOP MOTO building shown
  in `ladder-location.png` with the five-pose repeating rear-view cycle in
  `ladder-climb.png`. Those poses plant their feet on different rungs, so they
  hang from the head's column instead of the shared feet pivot every other
  Billy pose uses. Up at the ladder's base grabs it and snaps Billy onto
  its x; up and down climb at `FighterStats.climb_speed` with one pose per
  `climb_pose_pixels`; the top rung clamps the climb; reaching the base with
  down held, or sideways input at the base, steps off. The body stays on the
  ground plane while the `Visuals` node rises, exactly like the jump.
- Implemented: the top rung is the SCOOP building's stone cornice. Billy steps
  onto it, walks it with idle and walk poses, and climbs down the building's
  second ladder to the street; down over either ladder puts him back on its
  rungs. A ledge is a `ClimbPlatform`: a height above the ground plane plus
  the span of stage x its surface covers, so the belt keeps one ground plane
  and only the visuals rise. Its ends stop Billy rather than drop him.
- Implemented: while on the ladder Billy cannot be hit and drops attack,
  kick, and jump presses instead of buffering them. Because that
  invulnerability is untimed and the ladder stands inside the encounter's
  locked arena, the level closes every ladder while the encounter runs and
  opens them again when it is cleared.
- Ladders are `Ladder` areas on collision layer 9 that the player's
  `ClimbComponent` queries; the prototype alley places both of the SCOOP
  building's, at x 522 and x 778, each centred on the rails the art draws
  (513.5/529.5 and 769.5/785.5). Both lead to the one `ScoopLedge`, whose
  surface is the cornice's top row at world y 25, so each climbs 135 px.
- The band is no longer fixed. The stage slice reaches 56 px above the world
  origin (`1232x272+0+208`, drawn at y −56), and the camera raises its band by
  Billy's own elevation until `limit_top` stops it, so the climb reads as a
  vertical scroll and his whole sprite stays on screen at the top. A jump
  deliberately does not move the band.
- The encounter's trigger waits for a player on the ground plane, so crossing
  x 640 along the ledge does not start a fight that would only drop Billy off
  it.

Avoid implementing inventory, online multiplayer, elaborate AnimationTrees, or boss systems before the first encounter is enjoyable.
