class_name HurtboxComponent
extends Area2D

signal hit_received(attack_data: AttackData, knockback: Vector2, source: Node2D)

@export var health_component: HealthComponent

var is_invulnerable: bool = false


func _ready() -> void:
	assert(health_component != null, "HurtboxComponent requires HealthComponent")


func receive_attack(attack_data: AttackData, knockback: Vector2, source: Node2D) -> bool:
	if attack_data == null or is_invulnerable or health_component.is_dead():
		return false
	# Only terrain-aware stages add a vertical combat axis. Ordinary Stage 1
	# actors both report zero and preserve their existing jump/combat rules.
	var receiver := get_parent() as Node2D
	if source != null and receiver != null and source.has_method(&"combat_elevation") and receiver.has_method(&"combat_elevation"):
		if absf(float(source.call(&"combat_elevation")) - float(receiver.call(&"combat_elevation"))) > 32.0:
			return false

	health_component.take_damage(attack_data.damage)
	hit_received.emit(attack_data, knockback, source)
	return true


func damage_receiver_id() -> int:
	return health_component.get_instance_id()
