class_name PlayerVisuals
extends Node2D

@export var animated_sprite: AnimatedSprite2D

var _last_facing: float = 1.0


func _ready() -> void:
	assert(animated_sprite != null, "PlayerVisuals requires AnimatedSprite2D")


func sync(state: StringName, movement_direction: Vector2) -> void:
	var animation_name := _animation_for_state(state, movement_direction)
	var is_vertical_walk := (
		state == PlayerStateMachine.MOVE
		and absf(movement_direction.y) >= absf(movement_direction.x)
	)
	if not is_zero_approx(movement_direction.x):
		_last_facing = signf(movement_direction.x)

	animated_sprite.flip_h = not is_vertical_walk and _last_facing < 0.0
	if animated_sprite.animation == animation_name:
		return

	animated_sprite.play(animation_name)
	animated_sprite.set_frame_and_progress(0, 0.0)


func _animation_for_state(state: StringName, movement_direction: Vector2) -> StringName:
	if state == PlayerStateMachine.MOVE:
		return _walk_animation(movement_direction)
	if state == PlayerStateMachine.ATTACK:
		return &"punch"
	if state == PlayerStateMachine.HITSTUN:
		return &"hurt"
	if state == PlayerStateMachine.KNOCKDOWN:
		return &"knockdown"
	if state == PlayerStateMachine.DEAD:
		return &"death"
	return &"idle"


func _walk_animation(movement_direction: Vector2) -> StringName:
	if absf(movement_direction.y) >= absf(movement_direction.x):
		if movement_direction.y < 0.0:
			return &"walk_up"
		return &"walk_down"
	return &"walk_down"
