class_name CombatComponent
extends Node

signal attack_started
signal attack_finished

@export_range(1, 120, 1) var attack_duration_frames: int = 18

var attack_frame: int = 0
var is_attacking: bool = false


func try_start_attack() -> bool:
	if is_attacking:
		return false

	is_attacking = true
	attack_frame = 0
	attack_started.emit()
	return true


func physics_tick() -> void:
	if not is_attacking:
		return

	attack_frame += 1
	if attack_frame >= attack_duration_frames:
		_finish_attack()


func cancel_attack() -> void:
	if not is_attacking:
		return
	_finish_attack()


func _finish_attack() -> void:
	is_attacking = false
	attack_frame = 0
	attack_finished.emit()

