class_name JumpComponent
extends Node

signal jumped
signal landed

@export var body: CharacterBody2D
@export var visual_target: Node2D

var ground_position: Vector2 = Vector2.ZERO
var jump_height: float = 0.0
var jump_velocity: float = 0.0
var is_airborne: bool = false
var ground_elevation: float = 0.0
var terrain_motor: BeltTerrainMotor

var _takeoff_speed: float = 0.0
var _gravity: float = 0.0
var _grounded_visual_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	assert(body != null, "JumpComponent requires a CharacterBody2D")
	assert(visual_target != null, "JumpComponent requires a visual target")
	ground_position = body.global_position
	_grounded_visual_position = visual_target.position


func configure(stats: FighterStats) -> void:
	assert(stats != null, "JumpComponent requires FighterStats")
	_takeoff_speed = stats.jump_takeoff_speed
	_gravity = stats.jump_gravity


func try_jump(apex_scale: float = 1.0) -> bool:
	if _takeoff_speed <= 0.0 or _gravity <= 0.0:
		return false
	if is_airborne and not (terrain_motor != null and terrain_motor.consume_ledge_grace()):
		return false

	is_airborne = true
	jump_velocity = _takeoff_speed_for_apex_scale(apex_scale)
	jumped.emit()
	return true


func physics_tick(delta: float) -> void:
	sync_ground_position()
	if terrain_motor != null:
		terrain_motor.physics_jump(delta)
		return
	if not is_airborne:
		_apply_visual_height()
		return

	jump_velocity -= _gravity * delta
	jump_height += jump_velocity * delta
	if jump_height <= 0.0 and jump_velocity <= 0.0:
		jump_height = 0.0
		jump_velocity = 0.0
		is_airborne = false
		_apply_visual_height()
		landed.emit()
		return

	_apply_visual_height()


func sync_ground_position() -> void:
	ground_position = body.global_position


func land_immediately() -> void:
	var was_airborne := is_airborne
	jump_height = 0.0
	jump_velocity = 0.0
	is_airborne = false
	ground_position = body.global_position
	_apply_visual_height()
	if was_airborne:
		landed.emit()


func _apply_visual_height() -> void:
	visual_target.position = _grounded_visual_position + Vector2.UP * (ground_elevation + jump_height)


func has_ledge_grace() -> bool:
	return terrain_motor != null and terrain_motor.has_ledge_grace()


func gravity() -> float:
	return _gravity


func sync_visual_height() -> void:
	_apply_visual_height()


func _takeoff_speed_for_apex_scale(apex_scale: float) -> float:
	if is_equal_approx(apex_scale, 1.0):
		return _takeoff_speed

	var physics_ticks := float(
		ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)
	)
	var delta := 1.0 / maxf(physics_ticks, 1.0)
	var target_apex := _simulate_apex(_takeoff_speed, delta) * maxf(apex_scale, 0.01)
	var lower_speed := 0.0
	var upper_speed := _takeoff_speed
	while _simulate_apex(upper_speed, delta) < target_apex:
		upper_speed *= 2.0
	for _iteration: int in range(32):
		var candidate_speed := (lower_speed + upper_speed) * 0.5
		if _simulate_apex(candidate_speed, delta) < target_apex:
			lower_speed = candidate_speed
		else:
			upper_speed = candidate_speed
	return (lower_speed + upper_speed) * 0.5


func _simulate_apex(takeoff_speed: float, delta: float) -> float:
	var simulated_height := 0.0
	var maximum_height := 0.0
	var simulated_velocity := takeoff_speed
	while simulated_velocity > 0.0:
		simulated_velocity -= _gravity * delta
		simulated_height += simulated_velocity * delta
		maximum_height = maxf(maximum_height, simulated_height)
	return maximum_height
