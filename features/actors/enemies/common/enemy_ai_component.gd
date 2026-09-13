class_name EnemyAIComponent
extends Node

## Sense/decide worker for belt-scroller enemies. It mirrors the player's
## input component: each physics tick it publishes a movement direction, a
## facing, an intent, and a consumable attack request. It never moves the
## body or starts attacks itself.

const IDLE: StringName = &"idle"
const APPROACH: StringName = &"approach"
const RETREAT: StringName = &"retreat"
const ATTACK: StringName = &"attack"

@export_range(1.0, 200.0, 1.0) var attack_range_x: float = 30.0
@export_range(0.0, 50.0, 1.0) var depth_tolerance: float = 6.0
## Horizontal distance inside which the two body colliders overlap. A pure
## depth push from inside this band is blocked by the target's body, so the
## AI sidesteps out of it before aligning lanes.
@export_range(0.0, 100.0, 1.0) var body_clearance_x: float = 16.0
@export_range(0, 300, 1) var attack_cooldown_frames: int = 40
@export_range(0, 300, 1) var reaction_delay_frames: int = 20
@export_range(0, 300, 1) var recovery_delay_frames: int = 12
@export_range(0.0, 1.0, 0.05) var retreat_probability: float = 0.35
@export_range(0, 300, 1) var retreat_frames: int = 30
## Zero randomizes; any other value seeds the retreat roll deterministically.
@export var rng_seed: int = 0

var target: Node2D
var intent: StringName = IDLE
var movement_direction: Vector2 = Vector2.ZERO
var facing: float = -1.0

var _wait_frames_remaining: int = 0
var _cooldown_frames_remaining: int = 0
var _retreat_frames_remaining: int = 0
var _attack_requested: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_wait_frames_remaining = reaction_delay_frames


## Assigning a new target restarts the reaction delay so freshly spawned or
## retargeted enemies never charge on the same tick they notice Billy.
func set_target(next_target: Node2D) -> void:
	if next_target != target and next_target != null:
		_wait_frames_remaining = reaction_delay_frames
	target = next_target


func has_target() -> bool:
	return target != null and is_instance_valid(target)


func physics_tick(self_position: Vector2, can_act: bool) -> void:
	movement_direction = Vector2.ZERO
	if not has_target():
		intent = IDLE
		return

	var offset := target.global_position - self_position
	if not is_zero_approx(offset.x):
		facing = signf(offset.x)
	if _cooldown_frames_remaining > 0:
		_cooldown_frames_remaining -= 1
	if not can_act:
		intent = IDLE
		return
	if _wait_frames_remaining > 0:
		_wait_frames_remaining -= 1
		intent = IDLE
		return
	if _retreat_frames_remaining > 0:
		_retreat_frames_remaining -= 1
		movement_direction = Vector2(-facing, 0.0)
		intent = RETREAT
		return

	var in_horizontal_range := absf(offset.x) <= attack_range_x
	var in_depth_range := absf(offset.y) <= depth_tolerance
	if in_horizontal_range and in_depth_range:
		if _cooldown_frames_remaining <= 0:
			_attack_requested = true
			_cooldown_frames_remaining = attack_cooldown_frames
			intent = ATTACK
		else:
			intent = IDLE
		return

	var horizontal_step := 0.0 if in_horizontal_range else signf(offset.x)
	if not in_depth_range and absf(offset.x) < body_clearance_x:
		# Clear the target's body sideways (staying on the current side) so
		# the depth adjustment cannot wedge against it.
		horizontal_step = -signf(offset.x) if not is_zero_approx(offset.x) else -facing
	movement_direction = Vector2(
		horizontal_step,
		0.0 if in_depth_range else signf(offset.y)
	)
	intent = APPROACH


func consume_attack_request() -> bool:
	if not _attack_requested:
		return false
	_attack_requested = false
	return true


## The cooldown counts from the end of the punch, not from the request, so
## Williams never chains punches back to back.
func notify_attack_finished() -> void:
	_cooldown_frames_remaining = attack_cooldown_frames
	if _rng.randf() < retreat_probability:
		_retreat_frames_remaining = retreat_frames


func end_retreat() -> void:
	_retreat_frames_remaining = 0


func notify_hit() -> void:
	_attack_requested = false
	_retreat_frames_remaining = 0
	_wait_frames_remaining = 0
	movement_direction = Vector2.ZERO
	intent = IDLE


func notify_recovered() -> void:
	_wait_frames_remaining = recovery_delay_frames
	_cooldown_frames_remaining = maxi(_cooldown_frames_remaining, recovery_delay_frames)
