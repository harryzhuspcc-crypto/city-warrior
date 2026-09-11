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


func try_jump() -> bool:
	if is_airborne or _takeoff_speed <= 0.0 or _gravity <= 0.0:
		return false

	is_airborne = true
	jump_velocity = _takeoff_speed
	jumped.emit()
	return true


func physics_tick(delta: float) -> void:
	sync_ground_position()
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
	visual_target.position = _grounded_visual_position + Vector2.UP * jump_height
