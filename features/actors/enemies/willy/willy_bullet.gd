extends Node2D
## Visible single round: swept ground-plane contact, dodgeable by jumping
## or stepping out of its lane. No timers or references back to a dead boss.

var target: Player
var attack: AttackData
var direction: float = 1.0
var _life_frames: int = 120


func _physics_process(delta: float) -> void:
	_life_frames -= 1
	if _life_frames <= 0 or not is_instance_valid(target) or target.is_dead():
		queue_free()
		return
	var previous := global_position
	position.x += direction * 220.0 * delta
	var sweep := Rect2(Vector2(minf(previous.x, global_position.x), global_position.y - 6.0), Vector2(absf(global_position.x - previous.x) + 6.0, 12.0))
	var feet := Rect2(target.global_position + Vector2(-7, -8), Vector2(14, 8))
	if target.combat_elevation() <= 32.0 and sweep.intersects(feet):
		if target.hurtbox.receive_attack(attack, Vector2(direction * 90.0, 0), null):
			queue_free()


func _draw() -> void:
	draw_line(Vector2(-direction * 6.0, -36), Vector2(direction * 2.0, -36), Color("ffe6a0"), 2.0)
