class_name FighterStats
extends Resource

@export_category("Vitals")
@export_range(1, 1000, 1) var max_health: int = 100

@export_category("Ground Movement")
@export_range(1.0, 500.0, 1.0) var horizontal_speed: float = 90.0
@export_range(1.0, 500.0, 1.0) var depth_speed: float = 60.0

