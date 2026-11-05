class_name MovementComponent
extends Node

@export var body: CharacterBody2D

var _horizontal_speed: float = 0.0
var _depth_speed: float = 0.0
var terrain_motor: BeltTerrainMotor


func _ready() -> void:
	assert(body != null, "MovementComponent requires a CharacterBody2D")


func configure(stats: FighterStats) -> void:
	assert(stats != null, "MovementComponent requires FighterStats")
	_horizontal_speed = stats.horizontal_speed
	_depth_speed = stats.depth_speed


func move(direction: Vector2) -> void:
	var normalized_direction := direction.limit_length(1.0)
	_move_with_velocity(Vector2(
		normalized_direction.x * _horizontal_speed,
		normalized_direction.y * _depth_speed
	))


func move_at_speed(direction: Vector2, speed: float) -> void:
	_move_with_velocity(direction.normalized() * maxf(speed, 0.0))


func stop() -> void:
	_move_with_velocity(Vector2.ZERO)


func _move_with_velocity(next_velocity: Vector2) -> void:
	if terrain_motor != null:
		next_velocity = terrain_motor.resolve_velocity(next_velocity)
	body.velocity = next_velocity
	body.move_and_slide()
	if terrain_motor != null:
		terrain_motor.after_move()
