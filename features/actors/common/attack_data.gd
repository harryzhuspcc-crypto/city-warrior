class_name AttackData
extends Resource

@export var attack_name: StringName = &"punch"
@export var animation_name: StringName = &"punch"
@export_range(0, 120, 1) var startup_frames: int = 5
@export_range(1, 120, 1) var active_frames: int = 3
@export_range(1, 120, 1) var recovery_frames: int = 10
@export_range(0, 1000, 1) var damage: int = 10
@export_range(0, 120, 1) var hitstun_frames: int = 14
@export var knockback: Vector2 = Vector2(80.0, 0.0)
@export var hitbox_rect: Rect2 = Rect2(11.0, -37.0, 18.0, 18.0)
@export var knocks_down: bool = false
@export_range(-1, 1, 2) var hit_direction_multiplier: int = 1
@export_range(-1, 1, 2) var animation_facing_multiplier: int = 1
@export var reverse_facing_on_finish: bool = false
@export var starts_jump: bool = false
@export_range(0.01, 4.0, 0.01) var jump_height_scale: float = 1.0
@export var allow_air_movement: bool = false
@export var finishes_on_landing: bool = false
@export_range(0, 120, 1) var landing_hold_frame: int = 0
@export_range(0.0, 1000.0, 1.0) var movement_speed: float = 0.0
@export_range(0, 120, 1) var movement_start_frame: int = 0
@export_range(0, 120, 1) var movement_end_frame: int = 0
@export var animation_frame_starts: PackedInt32Array = PackedInt32Array([0])


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


func movement_is_active(frame: int) -> bool:
	return (
		movement_speed > 0.0
		and frame >= movement_start_frame
		and frame < movement_end_frame
	)


func animation_frame_for_attack_frame(frame: int) -> int:
	var result: int = 0
	for frame_index: int in range(animation_frame_starts.size()):
		if frame < animation_frame_starts[frame_index]:
			break
		result = frame_index
	return result
