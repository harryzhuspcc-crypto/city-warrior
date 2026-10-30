class_name StageTransition
extends Node
## Owns cinematic input, walk-off and fade. No global campaign singleton or
## simulated input events: the same player movement/visual workers are used.

signal transition_requested(scene_path: String)
signal transition_failed(scene_path: String)
signal intro_finished

const IDLE: StringName = &"idle"
const HOLD: StringName = &"hold"
const WALK: StringName = &"walk"
const FADE_OUT: StringName = &"fade_out"
const FADE_IN: StringName = &"fade_in"
const INTRO_HOLD: StringName = &"intro_hold"
const DONE: StringName = &"done"

@export var player: Player
@export var hud: Hud
@export var fade_rect: ColorRect
@export_file("*.tscn") var next_stage_path: String = ""
@export var show_intro: bool = false
@export var intro_title: String = "STAGE 2\nINDUSTRIAL YARD"
@export_range(1, 300, 1) var clear_hold_frames: int = 60
@export_range(1, 300, 1) var walk_frames: int = 78
@export_range(1, 120, 1) var fade_frames: int = 24
@export_range(1, 300, 1) var intro_hold_frames: int = 45
@export var walk_speed: float = 90.0

var phase: StringName = IDLE
var frame: int = 0
var _saved_collision_layer: int
var _saved_collision_mask: int
var _saved_invulnerable: bool
var _saved_physics: bool
var _saved_input: bool
var _owns_player: bool = false


func _ready() -> void:
	assert(player != null and hud != null and fade_rect != null, "StageTransition dependencies")
	_set_fade(0.0)
	if show_intro:
		_take_control()
		phase = FADE_IN
		_set_fade(1.0)
		# The level configures its HUD after child _ready() methods run.
		_show_intro_title.call_deferred()


func _show_intro_title() -> void:
	if phase == FADE_IN:
		hud.show_message(intro_title)


func is_busy() -> bool:
	return phase != IDLE


func has_next_stage() -> bool:
	return not next_stage_path.is_empty()


func begin_outro() -> bool:
	if is_busy() or not has_next_stage() or player.is_dead():
		return false
	_take_control()
	phase = HOLD
	frame = 0
	return true


func _physics_process(_delta: float) -> void:
	if phase in [IDLE, DONE]:
		return
	frame += 1
	match phase:
		HOLD:
			if frame >= clear_hold_frames:
				_enter(WALK)
		WALK:
			player.movement_component.move_at_speed(Vector2.RIGHT, walk_speed)
			player.jump_component.sync_ground_position()
			player.state_machine.transition_to(PlayerStateMachine.MOVE)
			player.visuals.sync(PlayerStateMachine.MOVE, Vector2.RIGHT)
			if frame >= walk_frames:
				player.velocity = Vector2.ZERO
				_enter(FADE_OUT)
		FADE_OUT:
			_set_fade(float(frame) / float(fade_frames))
			if frame >= fade_frames:
				_enter(DONE)
				_change_stage.call_deferred()
		FADE_IN:
			_set_fade(1.0 - float(frame) / float(fade_frames))
			if frame >= fade_frames:
				_enter(INTRO_HOLD)
		INTRO_HOLD:
			if frame >= intro_hold_frames:
				hud.hide_message()
				_release_control()
				_enter(IDLE)
				intro_finished.emit()


func _enter(next_phase: StringName) -> void:
	phase = next_phase
	frame = 0


func _set_fade(alpha: float) -> void:
	fade_rect.color = Color(0, 0, 0, clampf(alpha, 0.0, 1.0))
	fade_rect.visible = alpha > 0.0


func _take_control() -> void:
	if _owns_player:
		return
	_owns_player = true
	_saved_collision_layer = player.collision_layer
	_saved_collision_mask = player.collision_mask
	_saved_invulnerable = player.hurtbox.is_invulnerable
	_saved_physics = player.is_physics_processing()
	_saved_input = player.input_component.is_processing_unhandled_input()
	player.set_physics_process(false)
	player.input_component.set_process_unhandled_input(false)
	player.input_component.clear_buffered_actions()
	player.hair_grab_component.release()
	if is_instance_valid(player.throw_owner):
		player.throw_owner.release()
	player.combat_component.cancel_attack()
	player.attack_chain_component.reset()
	player.climb_component.release()
	player.jump_component.land_immediately()
	player.hit_reaction_component.reset()
	player.velocity = Vector2.ZERO
	# Only the cinematic actor ignores walls, so he can actually leave the
	# screen instead of endlessly walking against its right-edge collider.
	player.collision_layer = 0
	player.collision_mask = 0
	player.hurtbox.is_invulnerable = true
	player.state_machine.transition_to(PlayerStateMachine.IDLE)
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.ZERO)


func _release_control() -> void:
	if not _owns_player:
		return
	_owns_player = false
	player.collision_layer = _saved_collision_layer
	player.collision_mask = _saved_collision_mask
	player.hurtbox.is_invulnerable = _saved_invulnerable
	player.input_component.clear_buffered_actions()
	player.input_component.set_process_unhandled_input(_saved_input)
	player.set_physics_process(_saved_physics)


func _change_stage() -> void:
	# Detached scene fixtures may observe the request but never replace the
	# running game. Deferring also keeps scene removal outside physics ticks.
	transition_requested.emit(next_stage_path)
	if get_tree().current_scene != get_parent():
		return
	var error := get_tree().change_scene_to_file(next_stage_path)
	if error != OK:
		push_error("Could not load next stage: %s (%s)" % [next_stage_path, error])
		_set_fade(0.0)
		_release_control()
		_enter(IDLE)
		transition_failed.emit(next_stage_path)
