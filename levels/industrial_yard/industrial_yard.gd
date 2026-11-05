extends PrototypeAlley

@export var terrain: BeltTerrainMap


func _ready() -> void:
	super._ready()
	terrain.attach_actor(player)
	player.climb_component.platform_entered.connect(_on_platform_entered)
	for encounter: EncounterController in encounter_controllers():
		encounter.enemy_spawned.connect(_attach_enemy.bind(float(encounter.get_meta(&"terrain_height", 0.0))))


func _attach_enemy(enemy: Node2D, height: float) -> void:
	enemy.set_meta(&"terrain_height", height)
	terrain.attach_actor(enemy)


func _physics_process(delta: float) -> void:
	camera.band_center_y = clampf(player.position.y - 84.0, 108.0, 204.0)
	if stage_transition != null and stage_transition.is_busy():
		return
	if state == PLAYING:
		_try_front_ladder_descent()
		if (
			_all_encounters_cleared()
			and not player.jump_component.is_airborne
			and not player.climb_component.is_elevated()
			and absf(player.combat_elevation() - 208.0) < 1.0
			and player.position.distance_to(exit.position) < 16.0
		):
			_finish_stage()
		return
	super._physics_process(delta)


func _on_encounter_started(encounter: EncounterController) -> void:
	super._on_encounter_started(encounter)
	# This ladder reconnects two fighting floors, unlike the safe upper awning.
	get_node("Ladders/FrontLadder").set_climbable(true)


func _on_platform_entered(platform: ClimbPlatform) -> void:
	if platform != get_node("FrontRoofLanding"):
		return
	player.climb_component.release()
	player.jump_component.ground_elevation = 208.0
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()


func _try_front_ladder_descent() -> void:
	var ladder := get_node("Ladders/FrontLadder") as Ladder
	if (
		not player.jump_component.is_airborne
		and not player.climb_component.is_elevated()
		and is_equal_approx(player.jump_component.ground_elevation, 208.0)
		and player.position.distance_to(ladder.position) < 12.0
		and Input.is_action_pressed(&"move_down")
	):
		player.jump_component.ground_elevation = 0.0
		player.climb_component.ground_elevation = 0.0
		player.climb_component.start_descent(ladder)


func _on_encounter_cleared() -> void:
	super._on_encounter_cleared()
	if _all_encounters_cleared():
		hud.set_stage_name("EXIT: GREEN DOOR")
