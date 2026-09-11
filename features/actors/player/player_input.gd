class_name PlayerInputComponent
extends Node

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const ATTACK: StringName = &"attack"

var movement_direction: Vector2 = Vector2.ZERO
var _attack_buffered: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ATTACK):
		_attack_buffered = true


func physics_tick() -> void:
	movement_direction = Input.get_vector(
		MOVE_LEFT,
		MOVE_RIGHT,
		MOVE_UP,
		MOVE_DOWN
	)
	if Input.is_action_just_pressed(ATTACK):
		_attack_buffered = true


func consume_attack() -> bool:
	if not _attack_buffered:
		return false

	_attack_buffered = false
	return true
