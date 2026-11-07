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
@export_range(1, 8, 1) var chord_window_frames: int = 3
@export_range(2, 30, 1) var double_tap_window_frames: int = 12

var movement_direction: Vector2 = Vector2.ZERO
var attack_buffer_frames_remaining: int = 0
var kick_buffer_frames_remaining: int = 0
var jump_buffer_frames_remaining: int = 0

var _elbow_buffer_frames_remaining: int = 0
var _back_kick_buffer_frames_remaining: int = 0
var _head_attack_buffer_frames_remaining: int = 0
var _head_attack_direction: float = 0.0
var _head_attack_pressed_frame: int = -1000
var _attack_pressed_frame: int = -1000
var _kick_pressed_frame: int = -1000
var _jump_pressed_frame: int = -1000
var _last_direction_tap: float = 0.0
var _last_direction_tap_frame: int = -1000
var _input_frame: int = 0
var _held_left_inputs: Dictionary[String, bool] = {}
var _held_right_inputs: Dictionary[String, bool] = {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(ATTACK):
		queue_attack()
	if event.is_action_pressed(KICK):
		queue_kick()
	if event.is_action_pressed(JUMP):
		queue_jump()
	_handle_direction_event(event, MOVE_LEFT, -1.0, _held_left_inputs)
	_handle_direction_event(event, MOVE_RIGHT, 1.0, _held_right_inputs)


func physics_tick() -> void:
	movement_direction = Input.get_vector(
		MOVE_LEFT,
		MOVE_RIGHT,
		MOVE_UP,
		MOVE_DOWN
	)


func end_physics_tick() -> void:
	attack_buffer_frames_remaining = maxi(attack_buffer_frames_remaining - 1, 0)
	kick_buffer_frames_remaining = maxi(kick_buffer_frames_remaining - 1, 0)
	jump_buffer_frames_remaining = maxi(jump_buffer_frames_remaining - 1, 0)
	_elbow_buffer_frames_remaining = maxi(_elbow_buffer_frames_remaining - 1, 0)
	_back_kick_buffer_frames_remaining = maxi(_back_kick_buffer_frames_remaining - 1, 0)
	_head_attack_buffer_frames_remaining = maxi(_head_attack_buffer_frames_remaining - 1, 0)
	_input_frame += 1
	if _input_frame - _last_direction_tap_frame > double_tap_window_frames:
		_last_direction_tap = 0.0
		_last_direction_tap_frame = -1000


func queue_attack() -> void:
	attack_buffer_frames_remaining = attack_buffer_frames
	_attack_pressed_frame = _input_frame
	kick_buffer_frames_remaining = 0
	_kick_pressed_frame = -1000
	if _is_recent_jump_press():
		_queue_elbow_chord()


func queue_kick() -> void:
	kick_buffer_frames_remaining = attack_buffer_frames
	_kick_pressed_frame = _input_frame
	attack_buffer_frames_remaining = 0
	_attack_pressed_frame = -1000
	if _is_recent_jump_press():
		_queue_back_kick_chord()


func queue_jump() -> void:
	# A directional jump overrides a pending double-tap attack.
	_head_attack_buffer_frames_remaining = 0
	_head_attack_direction = 0.0
	_last_direction_tap = 0.0
	_last_direction_tap_frame = -1000
	jump_buffer_frames_remaining = attack_buffer_frames
	_jump_pressed_frame = _input_frame
	if _is_recent_attack_press():
		_queue_elbow_chord()
	elif _is_recent_kick_press():
		_queue_back_kick_chord()


func queue_direction_tap(horizontal_direction: float) -> void:
	if is_zero_approx(horizontal_direction) or _is_recent_jump_press():
		return
	var tap_direction := signf(horizontal_direction)
	if (
		tap_direction == _last_direction_tap
		and _input_frame - _last_direction_tap_frame <= double_tap_window_frames
	):
		_head_attack_pressed_frame = _input_frame
		_head_attack_direction = tap_direction
		_head_attack_buffer_frames_remaining = attack_buffer_frames
		_last_direction_tap = 0.0
		_last_direction_tap_frame = -1000
		return
	_last_direction_tap = tap_direction
	_last_direction_tap_frame = _input_frame


## Grab controls bypass the ordinary chord delay. A chord containing jump
## is still a throw, never an elbow/back kick or an actual jump.
func consume_grab_action() -> StringName:
	var action: StringName = &""
	if (
		attack_buffer_frames_remaining > 0
		or jump_buffer_frames_remaining > 0
		or _elbow_buffer_frames_remaining > 0
		or _back_kick_buffer_frames_remaining > 0
	):
		action = &"throw"
	elif kick_buffer_frames_remaining > 0:
		action = &"knee"
	if action != &"":
		clear_buffered_actions()
	return action


func consume_elbow_chord() -> bool:
	if _elbow_buffer_frames_remaining <= 0:
		return false
	_elbow_buffer_frames_remaining = 0
	return true


func consume_back_kick_chord() -> bool:
	if _back_kick_buffer_frames_remaining <= 0:
		return false
	_back_kick_buffer_frames_remaining = 0
	return true


func consume_head_attack_direction() -> float:
	# Give K the same chord window as J/L, regardless of key event order.
	if (
		_head_attack_buffer_frames_remaining <= 0
		or _input_frame - _head_attack_pressed_frame < chord_window_frames
	):
		return 0.0
	var result := _head_attack_direction
	_head_attack_buffer_frames_remaining = 0
	_head_attack_direction = 0.0
	return result


func consume_ready_attack() -> bool:
	if _input_frame - _attack_pressed_frame < chord_window_frames:
		return false
	return consume_attack()


func consume_ready_kick() -> bool:
	if _input_frame - _kick_pressed_frame < chord_window_frames:
		return false
	return consume_kick()


func consume_ready_jump() -> bool:
	if _input_frame - _jump_pressed_frame < chord_window_frames:
		return false
	return consume_jump()


func consume_attack() -> bool:
	if attack_buffer_frames_remaining <= 0:
		return false
	attack_buffer_frames_remaining = 0
	_attack_pressed_frame = -1000
	return true


func consume_kick() -> bool:
	if kick_buffer_frames_remaining <= 0:
		return false
	kick_buffer_frames_remaining = 0
	_kick_pressed_frame = -1000
	return true


func consume_jump() -> bool:
	if jump_buffer_frames_remaining <= 0:
		return false
	jump_buffer_frames_remaining = 0
	_jump_pressed_frame = -1000
	return true


func clear_buffered_actions() -> void:
	attack_buffer_frames_remaining = 0
	kick_buffer_frames_remaining = 0
	jump_buffer_frames_remaining = 0
	_elbow_buffer_frames_remaining = 0
	_back_kick_buffer_frames_remaining = 0
	_head_attack_buffer_frames_remaining = 0
	_head_attack_direction = 0.0
	_attack_pressed_frame = -1000
	_kick_pressed_frame = -1000
	_jump_pressed_frame = -1000
	_last_direction_tap = 0.0
	_last_direction_tap_frame = -1000
	_held_left_inputs.clear()
	_held_right_inputs.clear()


func _is_recent_attack_press() -> bool:
	return (
		attack_buffer_frames_remaining > 0
		and absi(_input_frame - _attack_pressed_frame) <= chord_window_frames
	)


func _is_recent_kick_press() -> bool:
	return (
		kick_buffer_frames_remaining > 0
		and absi(_input_frame - _kick_pressed_frame) <= chord_window_frames
	)


func _is_recent_jump_press() -> bool:
	return (
		jump_buffer_frames_remaining > 0
		and absi(_input_frame - _jump_pressed_frame) <= chord_window_frames
	)


func _queue_elbow_chord() -> void:
	_elbow_buffer_frames_remaining = attack_buffer_frames
	_back_kick_buffer_frames_remaining = 0
	attack_buffer_frames_remaining = 0
	jump_buffer_frames_remaining = 0
	_attack_pressed_frame = -1000
	_jump_pressed_frame = -1000


func _queue_back_kick_chord() -> void:
	_back_kick_buffer_frames_remaining = attack_buffer_frames
	_elbow_buffer_frames_remaining = 0
	kick_buffer_frames_remaining = 0
	jump_buffer_frames_remaining = 0
	_kick_pressed_frame = -1000
	_jump_pressed_frame = -1000


func _handle_direction_event(
	event: InputEvent,
	action: StringName,
	direction: float,
	held_inputs: Dictionary[String, bool]
) -> void:
	var event_id := _input_event_id(event)
	if event.is_action_pressed(action):
		if held_inputs.is_empty():
			queue_direction_tap(direction)
		held_inputs[event_id] = true
	elif event.is_action_released(action):
		held_inputs.erase(event_id)


func _input_event_id(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event != null:
		var code := key_event.physical_keycode
		if code == 0:
			code = key_event.keycode
		return "%d:key:%d" % [event.device, code]
	var button_event := event as InputEventJoypadButton
	if button_event != null:
		return "%d:button:%d" % [event.device, button_event.button_index]
	var motion_event := event as InputEventJoypadMotion
	if motion_event != null:
		return "%d:axis:%d:%d" % [
			event.device,
			motion_event.axis,
			int(signf(motion_event.axis_value)),
		]
	return "%d:%s" % [event.device, event.as_text()]
