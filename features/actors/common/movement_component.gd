class_name MovementComponent
extends Node

@export var body: CharacterBody2D

var _horizontal_speed: float = 0.0
var _depth_speed: float = 0.0


func _ready() -> void:
	assert(body != null, "MovementComponent requires a CharacterBody2D")


func configure(stats: FighterStats) -> void:
	assert(stats != null, "MovementComponent requires FighterStats")
	_horizontal_speed = stats.horizontal_speed
	_depth_speed = stats.depth_speed


func move(direction: Vector2) -> void:
	var normalized_direction := direction.limit_length(1.0)
	body.velocity = Vector2(
		normalized_direction.x * _horizontal_speed,
		normalized_direction.y * _depth_speed
	)
	body.move_and_slide()


func stop() -> void:
	body.velocity = Vector2.ZERO
	body.move_and_slide()

