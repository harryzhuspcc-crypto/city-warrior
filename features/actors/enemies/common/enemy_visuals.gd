class_name EnemyVisuals
extends Node2D

const IDLE_ANIMATION: StringName = &"idle"
const WALK_ANIMATION: StringName = &"walk"
const WALK_UP_ANIMATION: StringName = &"walk_up"

@export var animated_sprite: AnimatedSprite2D


func _ready() -> void:
	assert(animated_sprite != null, "EnemyVisuals requires AnimatedSprite2D")


## Locomotion presentation. Artwork is authored facing right; negative facing
## mirrors it.
func sync_locomotion(is_moving: bool, movement_direction: Vector2, facing: float) -> void:
	animated_sprite.flip_h = facing < 0.0
	var animation_name := IDLE_ANIMATION
	if is_moving:
		animation_name = WALK_ANIMATION
		if (
			absf(movement_direction.y) > absf(movement_direction.x)
			and movement_direction.y < 0.0
		):
			animation_name = WALK_UP_ANIMATION
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	var animation_changed := animated_sprite.animation != animation_name
	animated_sprite.play(animation_name)
	if animation_changed:
		animated_sprite.set_frame_and_progress(0, 0.0)


## Frame-driven presentation for attacks and hit reactions. The caller's
## logical frame counter and pose schedule select the pose; playback never
## free-runs.
func sync_scheduled_pose(
	animation_name: StringName,
	frame: int,
	frame_starts: PackedInt32Array,
	facing: float
) -> void:
	animated_sprite.flip_h = facing < 0.0
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	animated_sprite.pause()
	var pose_index := PoseSchedule.pose_index(
		frame,
		frame_starts,
		animated_sprite.sprite_frames.get_frame_count(animation_name)
	)
	animated_sprite.set_frame_and_progress(pose_index, 0.0)
