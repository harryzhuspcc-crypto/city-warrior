class_name HurtboxComponent
extends Area2D

signal hit_received(attack_data: AttackData, knockback: Vector2, source: Node2D)

@export var health_component: HealthComponent


func _ready() -> void:
	assert(health_component != null, "HurtboxComponent requires HealthComponent")


func receive_attack(attack_data: AttackData, knockback: Vector2, source: Node2D) -> bool:
	if attack_data == null or health_component.is_dead():
		return false

	health_component.take_damage(attack_data.damage)
	hit_received.emit(attack_data, knockback, source)
	return true


func damage_receiver_id() -> int:
	return health_component.get_instance_id()
