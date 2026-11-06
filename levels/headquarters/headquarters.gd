extends PrototypeAlley
## Finale wiring: traps stop during cinematics/death; all arenas must clear
## before Billy can reach Marian at the dragon door and finish the campaign.

@export var terrain: BeltTerrainMap
@export var wall_traps: Array[TimedWallTrap] = []
var _boss: EnemyFighter


func _ready() -> void:
	super._ready()
	hud.stage_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hud.stage_label.add_theme_constant_override(&"outline_size", 2)
	hud.message_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hud.message_label.add_theme_constant_override(&"outline_size", 2)
	terrain.attach_actor(player)
	stage_transition.intro_finished.connect(_start_traps)
	for encounter: EncounterController in encounter_controllers():
		encounter.enemy_spawned.connect(_attach_enemy.bind(encounter))


func _start_traps() -> void:
	if state != PLAYING:
		return
	for trap: TimedWallTrap in wall_traps:
		trap.enabled = true
	hud.set_stage_name("WALLS: AMBER = WAIT / ONE HIT KILLS")


func _attach_enemy(enemy: Node2D, encounter: EncounterController) -> void:
	terrain.attach_actor(enemy)
	if encounter == boss_encounter:
		_boss = enemy as EnemyFighter
		_boss.health_component.health_changed.connect(_show_boss_health)
		_show_boss_health(_boss.health_component.current_health, _boss.health_component.maximum_health())


func _show_boss_health(current: int, maximum: int) -> void:
	if state == PLAYING:
		hud.set_stage_name("WILLY  %d / %d" % [current, maximum])


func _physics_process(delta: float) -> void:
	camera.band_center_y = player.position.y - 84.0
	if stage_transition.is_busy():
		return
	if state == PLAYING:
		if _all_encounters_cleared() and player.position.distance_to(exit.position) < 18.0:
			_finish_stage()
		return
	super._physics_process(delta)


func _on_encounter_started(encounter: EncounterController) -> void:
	super._on_encounter_started(encounter)
	if encounter != boss_encounter:
		hud.set_stage_name(stage_name)


func _on_encounter_cleared() -> void:
	super._on_encounter_cleared()
	if _all_encounters_cleared():
		hud.set_stage_name("WILLY DEFEATED - REACH THE DRAGON DOOR")


func _stop_traps() -> void:
	for trap: TimedWallTrap in wall_traps:
		trap.enabled = false


func _on_player_died() -> void:
	_stop_traps()
	super._on_player_died()


func _finish_stage() -> void:
	_stop_traps()
	player.combat_component.cancel_attack()
	player.input_component.clear_buffered_actions()
	player.hurtbox.is_invulnerable = true
	player.set_physics_process(false)
	super._finish_stage()
