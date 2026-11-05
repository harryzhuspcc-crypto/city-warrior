class_name ClimbComponent
extends Node
## Owns ladder climbing for an actor: grabbing a ladder found under the feet,
## climbing between the base and the top rung, stepping onto the ledge a ladder
## leads to, and the visual rise. Like the jump, the body stays on the ground
## plane and only visual_target moves — a ledge is a height, not a second floor.

signal climb_started(ladder: Ladder)
signal climb_finished
signal platform_entered(platform: ClimbPlatform)
signal platform_exited

@export var body: CharacterBody2D
@export var visual_target: Node2D
## Invulnerable while climbing: the actor is off the ground plane.
@export var hurtbox: HurtboxComponent
@export_flags_2d_physics var ladder_mask: int = 256

## Actor bodies share collision layer 2. An actor off the ground plane passes
## over anyone standing under the ledge, so that layer is dropped from its
## mask until it comes back down.
const ACTOR_BODY_LAYER: int = 2

var is_climbing: bool = false
var is_on_platform: bool = false
## Pixels above the ground plane, on a rung or on a ledge.
var climb_height: float = 0.0
var ladder: Ladder
var platform: ClimbPlatform
var _climb_speed: float = 0.0
var _pose_pixels: float = 8.0
var _grounded_visual_position: Vector2 = Vector2.ZERO
## Optional terrain floor beneath a ladder; zero preserves Stage 1.
var ground_elevation: float = 0.0


func _ready() -> void:
	assert(body != null, "ClimbComponent requires a CharacterBody2D")
	assert(visual_target != null, "ClimbComponent requires a visual target")
	assert(hurtbox != null, "ClimbComponent requires a HurtboxComponent")
	_grounded_visual_position = visual_target.position


func configure(stats: FighterStats) -> void:
	assert(stats != null, "ClimbComponent requires FighterStats")
	_climb_speed = stats.climb_speed
	_pose_pixels = stats.climb_pose_pixels


## Grabs the climbable ladder whose grab zone covers the body's feet. The
## body snaps onto the ladder's base so the top of the climb is an absolute
## world position however deep in the strip the actor was standing.
## Returns false when no climbable ladder is there.
func try_grab() -> bool:
	if is_climbing:
		return true
	var found := _ladder_at_feet()
	if found == null:
		return false
	ladder = found
	is_climbing = true
	climb_height = 0.0
	body.global_position = found.global_position
	_leave_the_ground_plane()
	_apply_visual_height()
	climb_started.emit(found)
	return true


## Enter a ladder from a terrain-supported roof rather than an abstract ledge.
func start_descent(next_ladder: Ladder) -> void:
	ladder = next_ladder
	platform = null
	is_on_platform = false
	is_climbing = true
	climb_height = next_ladder.top_height()
	body.global_position = next_ladder.global_position
	_leave_the_ground_plane()
	_apply_visual_height()
	climb_started.emit(next_ladder)


## Climbs by the vertical input (negative y is up) at the configured speed.
## Reaching the top of a ladder that leads to a ledge steps onto it. Reaching
## the base with down held, or sideways input within one step of the base,
## steps off the ladder.
func physics_tick(input_direction: Vector2, delta: float) -> void:
	if not is_climbing:
		return
	if not is_instance_valid(ladder):
		# The ladder left the scene under the actor (a despawn, a streamed
		# level). Step off rather than dereference a freed node every tick.
		release()
		return
	var step := _climb_speed * delta
	if input_direction.y < 0.0:
		var top := ladder.top_height()
		climb_height = minf(climb_height + step, top)
		if ladder.platform != null and is_equal_approx(climb_height, top):
			_step_onto_platform(ladder.platform)
			return
	elif input_direction.y > 0.0:
		climb_height = maxf(climb_height - step, 0.0)
		if is_zero_approx(climb_height):
			release()
			return
	elif climb_height <= step and not is_zero_approx(input_direction.x):
		# Within one step of the base, sideways input walks off the ladder.
		release()
		return
	_apply_visual_height()


## Holds the actor on the ledge for one tick. Down over a ladder that serves
## this ledge steps back onto its top rung; returns true on the tick that
## happens so the caller can hand the tick to the climb.
func platform_tick(input_direction: Vector2) -> bool:
	if not is_on_platform:
		return false
	if not is_instance_valid(platform):
		# The ledge left the scene under the actor, as a ladder can.
		release()
		return false
	if input_direction.y > 0.0:
		var below := _ladder_at_feet()
		if below != null and below.platform == platform:
			_step_onto_ladder(below)
			return true
	return false


## Keeps the body on the ledge's surface after the caller has walked it. The
## ends stop the actor: a ledge in this prototype has no fall.
func hold_on_platform() -> void:
	if not is_on_platform or not is_instance_valid(platform):
		return
	body.global_position = Vector2(
		platform.hold_x(body.global_position.x),
		platform.global_position.y
	)


## True while the actor is off the ground plane on a rung or a ledge.
func is_elevated() -> bool:
	return is_climbing or is_on_platform


## Pixels the visuals stand above the ground plane; zero once back down.
func elevation() -> float:
	return climb_height


## Lets go of the ladder or the ledge; the visuals return to the ground plane.
func release() -> void:
	if not is_elevated():
		return
	if is_on_platform:
		is_on_platform = false
		platform = null
		platform_exited.emit()
	is_climbing = false
	climb_height = 0.0
	ladder = null
	hurtbox.is_invulnerable = false
	body.set_collision_mask_value(ACTOR_BODY_LAYER, true)
	_apply_visual_height()
	climb_finished.emit()


## Pose of a repeating climb cycle, advancing one pose per climb_pose_pixels.
## The caller passes the sprite's own frame count so the cycle can never
## disagree with the artwork.
func pose_index(pose_count: int) -> int:
	if _pose_pixels <= 0.0 or pose_count <= 0:
		return 0
	return int(floorf(climb_height / _pose_pixels)) % pose_count


## The top rung is the ledge's surface: the actor keeps its height, leaves the
## rungs, and stands on the ledge's own depth line.
func _step_onto_platform(next_platform: ClimbPlatform) -> void:
	is_climbing = false
	ladder = null
	platform = next_platform
	is_on_platform = true
	climb_height = next_platform.height
	body.global_position.y = next_platform.global_position.y
	_apply_visual_height()
	platform_entered.emit(next_platform)


## Steps off the ledge onto a ladder's top rung, keeping the height so the
## descent starts exactly where the surface was.
func _step_onto_ladder(next_ladder: Ladder) -> void:
	is_on_platform = false
	platform = null
	platform_exited.emit()
	ladder = next_ladder
	is_climbing = true
	climb_height = minf(climb_height, next_ladder.top_height())
	body.global_position = next_ladder.global_position
	_apply_visual_height()
	climb_started.emit(next_ladder)


func _leave_the_ground_plane() -> void:
	hurtbox.is_invulnerable = true
	body.set_collision_mask_value(ACTOR_BODY_LAYER, false)


func _ladder_at_feet() -> Ladder:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = body.global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = ladder_mask
	var space := body.get_world_2d().direct_space_state
	for result: Dictionary in space.intersect_point(query, 8):
		var candidate := result.get("collider") as Ladder
		if candidate != null and candidate.is_climbable:
			if not is_elevated() and candidate.base_elevation >= 0.0 and body.has_method(&"combat_elevation"):
				if absf(float(body.call(&"combat_elevation")) - candidate.base_elevation) > 1.0:
					continue
			return candidate
	return null


func _apply_visual_height() -> void:
	visual_target.position = _grounded_visual_position + Vector2.UP * (ground_elevation + climb_height)
