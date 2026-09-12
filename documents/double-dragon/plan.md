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
├── EncounterController
├── Camera2D
└── HUD (CanvasLayer)
```

Separate stage art from collision. Use invisible `StaticBody2D` boundaries to define the walkable strip.

The encounter controller should:

1. Spawn three enemies.
2. Lock camera movement.
3. Detect when all enemies have died.
4. Unlock the camera.
5. Finish the prototype when the player reaches the exit.

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
- Implement the following combos only after Williams and the enemy
  fighting/damage feedback loop exist.
- Add the three-hit punch sequence shown in `three-hit-punch.png`. The first
  two connected punches advance the chain; only the third connected input uses
  the rising finisher. Whiffing must not advance the combo counter.
- Add the three-hit kick sequence shown in `three-hit-kick.png`. The first two
  connected kicks advance the chain; only the third connected input uses the
  turning/back-kick finisher. Whiffing must not advance the combo counter.
- Combo progression must be driven by confirmed enemy hits, not merely by
  button presses or animation completion.

Avoid implementing inventory, online multiplayer, elaborate AnimationTrees, or boss systems before the first encounter is enjoyable.
