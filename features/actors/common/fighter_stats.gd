class_name FighterStats
extends Resource

@export_category("Vitals")
@export_range(1, 1000, 1) var max_health: int = 100

@export_category("Ground Movement")
@export_range(1.0, 500.0, 1.0) var horizontal_speed: float = 90.0
@export_range(1.0, 500.0, 1.0) var depth_speed: float = 60.0

@export_category("Jump")
@export_range(1.0, 1000.0, 0.1) var jump_takeoff_speed: float = 252.4
@export_range(1.0, 2000.0, 1.0) var jump_gravity: float = 600.0
