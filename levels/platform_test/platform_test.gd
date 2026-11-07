extends Node2D
## Standalone scene with authored scenery and actors visible in the editor.
@export var spawn_enemies: bool = true
const SPAWNS := [Vector2(65, 235), Vector2(150, 235), Vector2(250, 235), Vector2(370, 235)]
var enemies: Array[EnemyFighter] = []
@onready var terrain: BeltTerrainMap = $Terrain
@onready var player: Player = $Actors/Player
@onready var status: Label = $HUD/Status


func _ready() -> void:
	terrain.attach_actor(player)
	for child: Node in $Actors.get_children():
		if not child is EnemyFighter:
			continue
		var enemy := child as EnemyFighter
		if not spawn_enemies:
			$Actors.remove_child(enemy)
			enemy.queue_free()
			continue
		# Authored position is the visible foot location for editor placement.
		# Runtime movement uses ground depth plus a separate elevation.
		enemy.position.y += float(enemy.get_meta(&"terrain_height", 0.0))
		terrain.attach_actor(enemy)
		enemy.set_target(player)
		enemies.append(enemy)


func _process(_delta: float) -> void:
	status.text = "HP: %d   Height: %03d   %s" % [player.health_component.current_health, player.terrain_motor.elevation(), "AIRBORNE" if player.jump_component.is_airborne else "GROUNDED"]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	if key.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_3:
		reset_player(key.physical_keycode - KEY_0)


func reset_player(tier: int) -> void:
	player.combat_component.cancel_attack()
	player.input_component.clear_buffered_actions()
	player.position = SPAWNS[tier]
	player.velocity = Vector2.ZERO
	player.jump_component.ground_elevation = tier * 32.0
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()
