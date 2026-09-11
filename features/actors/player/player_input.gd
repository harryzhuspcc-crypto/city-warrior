class_name PlayerInputComponent
extends Node

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_UP: StringName = &"move_up"
const MOVE_DOWN: StringName = &"move_down"
const ATTACK: StringName = &"attack"
const KICK: StringName = &"kick"
const JUMP: StringName = &"jump"

@export_range(1, 30, 1) var attack_buffer_frames: int = 8

var movement_direction: Vector2 = Vector2.ZERO
var attack_buffer_frames_remaining: int = 0
var kick_buffer_frames_remaining: int = 0
var jump_buffer_frames_remaining: int = 0
var _attack_event_captured: bool = false
var _kick_event_captured: bool = false
var _jump_event_captured: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ATTACK) and not event.is_echo():
		queue_attack()
		_attack_event_captured = true
	if event.is_action_pressed(KICK) and not event.is_echo():
		queue_kick()
		_kick_event_captured = true
	if event.is_action_pressed(JUMP) and not event.is_echo():
		queue_jump()
		_jump_event_captured = true


func physics_tick() -> void:
	movement_direction = Input.get_vector(
		MOVE_LEFT,
		MOVE_RIGHT,
		MOVE_UP,
		MOVE_DOWN
	)
	if Input.is_action_just_pressed(ATTACK) and not _attack_event_captured:
		queue_attack()
	if Input.is_action_just_pressed(KICK) and not _kick_event_captured:
		queue_kick()
	if Input.is_action_just_pressed(JUMP) and not _jump_event_captured:
		queue_jump()


func end_physics_tick() -> void:
	attack_buffer_frames_remaining = maxi(attack_buffer_frames_remaining - 1, 0)
	kick_buffer_frames_remaining = maxi(kick_buffer_frames_remaining - 1, 0)
	jump_buffer_frames_remaining = maxi(jump_buffer_frames_remaining - 1, 0)
	_attack_event_captured = false
	_kick_event_captured = false
	_jump_event_captured = false


func queue_attack() -> void:
	attack_buffer_frames_remaining = attack_buffer_frames
	kick_buffer_frames_remaining = 0


func queue_kick() -> void:
	kick_buffer_frames_remaining = attack_buffer_frames
	attack_buffer_frames_remaining = 0


func queue_jump() -> void:
	jump_buffer_frames_remaining = attack_buffer_frames


func consume_attack() -> bool:
	if attack_buffer_frames_remaining <= 0:
		return false

	attack_buffer_frames_remaining = 0
	return true


func consume_kick() -> bool:
	if kick_buffer_frames_remaining <= 0:
		return false

	kick_buffer_frames_remaining = 0
	return true


func consume_jump() -> bool:
	if jump_buffer_frames_remaining <= 0:
		return false

	jump_buffer_frames_remaining = 0
	_attack_event_captured = false
	_kick_event_captured = false
	_jump_event_captured = false
	return true


func clear_buffered_actions() -> void:
	attack_buffer_frames_remaining = 0
	kick_buffer_frames_remaining = 0
	jump_buffer_frames_remaining = 0
