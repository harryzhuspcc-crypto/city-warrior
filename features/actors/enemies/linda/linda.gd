class_name Linda
extends EnemyFighter
## Uses the common fighter loop; punches close up and whips at longer range.

@export var whip_attack: AttackData
@export var punch_range: float = 30.0


func _ready() -> void:
	assert(whip_attack != null, "Linda requires a whip attack")
	super._ready()


func _try_start_ai_attack() -> bool:
	var attack := combat_component.attack_data
	if is_instance_valid(target) and absf(target.global_position.x - global_position.x) > punch_range:
		attack = whip_attack
	return combat_component.try_start_attack(attack)


func can_be_hair_grabbed() -> bool:
	# HairGrabComponent currently supports Williams' paired captive art only.
	return false
