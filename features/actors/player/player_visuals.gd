class_name PlayerVisuals
extends Node2D

const JUMP_ANIMATION: StringName = &"jump"
const IDLE_ANIMATION: StringName = &"idle"
const WALK_UP_ANIMATION: StringName = &"walk_up"
const WALK_DOWN_ANIMATION: StringName = &"walk_down"
const PUNCH_ANIMATION: StringName = &"punch"

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
	attack_frame_starts: PackedInt32Array = PackedInt32Array([0]),
	attack_animation_facing_multiplier: int = 1
) -> void:
	if not is_zero_approx(movement_direction.x):
		_last_facing = signf(movement_direction.x)
	var display_facing := _last_facing
	if state == PlayerStateMachine.ATTACK:
		display_facing *= float(attack_animation_facing_multiplier)
	animated_sprite.flip_h = display_facing < 0.0

	if state == PlayerStateMachine.ATTACK:
		_sync_attack_pose(attack_animation, attack_frame, attack_frame_starts)
		return
	if is_airborne:
		if animated_sprite.animation != JUMP_ANIMATION:
			animated_sprite.play(JUMP_ANIMATION)
		animated_sprite.pause()
		var jump_frame: int = 0 if jump_velocity >= 0.0 else 1
		animated_sprite.set_frame_and_progress(jump_frame, 0.0)
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


func set_facing(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction):
		return
	_last_facing = signf(horizontal_direction)
	animated_sprite.flip_h = _last_facing < 0.0


func _sync_attack_pose(
	animation_name: StringName,
	attack_frame: int,
	frame_starts: PackedInt32Array
) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	animated_sprite.pause()
	var pose_index: int = 0
	for frame_index: int in range(frame_starts.size()):
		if attack_frame < frame_starts[frame_index]:
			break
		pose_index = frame_index
	pose_index = mini(
		pose_index,
		animated_sprite.sprite_frames.get_frame_count(animation_name) - 1
	)
	animated_sprite.set_frame_and_progress(pose_index, 0.0)


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
