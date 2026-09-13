class_name HealthComponent
extends Node

signal health_changed(current_health: int, maximum_health: int)
signal damaged(amount: int)
signal died

var current_health: int = 0
var _maximum_health: int = 0


func configure(stats: FighterStats) -> void:
	assert(stats != null, "HealthComponent requires FighterStats")
	_maximum_health = stats.max_health
	current_health = _maximum_health
	health_changed.emit(current_health, _maximum_health)


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return

	current_health = maxi(current_health - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_health, _maximum_health)

	if current_health == 0:
		died.emit()


func restore_full_health() -> void:
	current_health = _maximum_health
	health_changed.emit(current_health, _maximum_health)


func is_dead() -> bool:
	return current_health <= 0


func maximum_health() -> int:
	return _maximum_health

