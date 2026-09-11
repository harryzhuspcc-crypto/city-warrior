class_name AttackData
extends Resource

@export var attack_name: StringName = &"punch"
@export var animation_name: StringName = &"punch"
@export_range(0, 120, 1) var startup_frames: int = 5
@export_range(1, 120, 1) var active_frames: int = 3
@export_range(0, 120, 1) var recovery_frames: int = 10
@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 120, 1) var hitstun_frames: int = 14
@export var knockback: Vector2 = Vector2(80.0, 0.0)
@export var hitbox_rect: Rect2 = Rect2(11.0, -37.0, 18.0, 18.0)


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames
