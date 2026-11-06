class_name Willy
extends EnemyFighter
## Shared fighter reactions with a telegraphed gunshot and a close-range kick.

const Bullet = preload("res://features/actors/enemies/willy/willy_bullet.gd")
@export var gun_attack: AttackData
@export var bullet_attack: AttackData
@export var gun_audio: AudioStreamPlayer2D


func _ready() -> void:
	super._ready()
	combat_component.attack_phase_changed.connect(_on_attack_phase_changed)


func can_be_hair_grabbed() -> bool:
	return false


func _try_start_ai_attack() -> bool:
	var close := is_instance_valid(target) and absf(target.global_position.x - global_position.x) < 42.0
	return combat_component.try_start_attack(null if close else gun_attack)


func _on_attack_phase_changed(_previous: StringName, next: StringName) -> void:
	if next != CombatComponent.ACTIVE or combat_component.current_attack_data != gun_attack:
		return
	var bullet := Bullet.new()
	bullet.target = target as Player
	bullet.attack = bullet_attack
	bullet.direction = combat_component.attack_facing
	bullet.position = position + Vector2(bullet.direction * 26.0, 0)
	get_parent().add_child(bullet)
	gun_audio.play()
