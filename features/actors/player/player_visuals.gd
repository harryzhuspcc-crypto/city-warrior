class_name PlayerVisuals
extends Node2D

const JUMP_ANIMATION: StringName = &"jump"
const IDLE_ANIMATION: StringName = &"idle"
const WALK_UP_ANIMATION: StringName = &"walk_up"
const WALK_DOWN_ANIMATION: StringName = &"walk_down"
const PUNCH_ANIMATION: StringName = &"punch"
const KICK_ANIMATION: StringName = &"kick"

@export var animated_sprite: AnimatedSprite2D

var _last_facing: float = 1.0
var _last_locomotion_animation: StringName = IDLE_ANIMATION


func _ready() -> void:
	assert(animated_sprite != null, "PlayerVisuals requires AnimatedSprite2D")


func sync(
	state: StringName,
	movement_direction: Vector2,
	is_airborne: bool = false,
	jump_velocity: float = 0.0,
	attack_animation: StringName = PUNCH_ANIMATION,
	attack_frame: int = 0,
	attack_startup_frames: int = 0
) -> void:
	if not is_zero_approx(movement_direction.x):
		_last_facing = signf(movement_direction.x)
	animated_sprite.flip_h = _last_facing < 0.0

	if is_airborne:
		if animated_sprite.animation != JUMP_ANIMATION:
			animated_sprite.play(JUMP_ANIMATION)
		animated_sprite.pause()
		var jump_frame: int = 0 if jump_velocity >= 0.0 else 1
		animated_sprite.set_frame_and_progress(jump_frame, 0.0)
		return
	if state == PlayerStateMachine.ATTACK and attack_animation == KICK_ANIMATION:
		_sync_kick_pose(attack_frame, attack_startup_frames)
		return

	if state == PlayerStateMachine.IDLE and movement_direction.is_zero_approx():
		_hold_last_locomotion_pose()
		return

	var animation_name := _animation_for_state(state, movement_direction, attack_animation)
	if state == PlayerStateMachine.MOVE:
		_last_locomotion_animation = animation_name

	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return

	var animation_changed := animated_sprite.animation != animation_name
	animated_sprite.play(animation_name)
	if animation_changed:
		animated_sprite.set_frame_and_progress(0, 0.0)


func _hold_last_locomotion_pose() -> void:
	if _last_locomotion_animation == IDLE_ANIMATION:
		if animated_sprite.animation != IDLE_ANIMATION or not animated_sprite.is_playing():
			animated_sprite.play(IDLE_ANIMATION)
		return

	if animated_sprite.animation != _last_locomotion_animation:
		animated_sprite.play(_last_locomotion_animation)
		animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.pause()


func _sync_kick_pose(attack_frame: int, startup_frames: int) -> void:
	if animated_sprite.animation != KICK_ANIMATION:
		animated_sprite.play(KICK_ANIMATION)
	animated_sprite.pause()
	var kick_frame: int = 0 if attack_frame < startup_frames else 1
	animated_sprite.set_frame_and_progress(kick_frame, 0.0)


func _animation_for_state(
	state: StringName,
	movement_direction: Vector2,
	attack_animation: StringName
) -> StringName:
	if state == PlayerStateMachine.MOVE:
		return _walk_animation(movement_direction)
	if state == PlayerStateMachine.ATTACK:
		return attack_animation
	if state == PlayerStateMachine.HITSTUN:
		return &"hurt"
	if state == PlayerStateMachine.KNOCKDOWN:
		return &"knockdown"
	if state == PlayerStateMachine.DEAD:
		return &"death"
	return IDLE_ANIMATION


func _walk_animation(movement_direction: Vector2) -> StringName:
	if absf(movement_direction.y) >= absf(movement_direction.x):
		if movement_direction.y < 0.0:
			return WALK_UP_ANIMATION
		return WALK_DOWN_ANIMATION
	return WALK_DOWN_ANIMATION
