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

@export_category("Ladders")
@export_range(1.0, 300.0, 1.0) var climb_speed: float = 48.0
## Distance climbed per pose of the repeating climb cycle.
@export_range(1.0, 40.0, 0.5) var climb_pose_pixels: float = 8.0

@export_category("Hit Reactions")
## Williams advances only while a staged reaction is still active.
@export var staged_hit_reactions: bool = false
@export_range(1, 120, 1) var status1_frames: int = 30
@export_range(1, 180, 1) var status2_frames: int = 60
@export_range(1, 300, 1) var knockdown_frames: int = 60
@export_range(1, 20, 1) var hits_before_knockdown: int = 3
@export_range(0, 300, 1) var hit_chain_reset_frames: int = 30
@export_range(0.0, 10.0, 0.05) var knockdown_knockback_scale: float = 1.5
@export var hurt_pose_starts: PackedInt32Array = PackedInt32Array([0, 6])
@export var knockdown_pose_starts: PackedInt32Array = PackedInt32Array([0, 8, 16, 46])
@export var death_pose_starts: PackedInt32Array = PackedInt32Array([0, 8, 16])

@export_category("Combo Chains")
## How long a combo chain stays open after a connected hit. A press later than
## this starts the chain again from its opener.
@export_range(0, 120, 1) var chain_window_frames: int = 24
