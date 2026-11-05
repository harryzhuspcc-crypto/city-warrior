extends PrototypeAlley
## Stage-specific wiring only; terrain shapes/support share the existing motor.

@export var terrain: BeltTerrainMap
@export var cliff_ladder: Ladder
@export var cliff_landing: ClimbPlatform


func _ready() -> void:
	super._ready()
	terrain.attach_actor(player)
	player.climb_component.platform_entered.connect(_on_platform_entered)
	for encounter: EncounterController in encounter_controllers():
		encounter.enemy_spawned.connect(_attach_enemy.bind(float(encounter.get_meta(&"terrain_height", 96.0))))


func _attach_enemy(enemy: Node2D, height: float) -> void:
	enemy.set_meta(&"terrain_height", height)
	terrain.attach_actor(enemy)


func _physics_process(delta: float) -> void:
	camera.band_center_y = player.position.y - 84.0
	if stage_transition.is_busy():
		return
	if state == PLAYING:
		_try_cliff_descent()
		if (
			_all_encounters_cleared()
			and not player.jump_component.is_airborne
			and not player.climb_component.is_elevated()
			and is_equal_approx(player.jump_component.ground_elevation, 224.0)
			and player.position.distance_to(exit.position) < 18.0
		):
			_finish_stage()
		return
	super._physics_process(delta)


func _on_platform_entered(platform: ClimbPlatform) -> void:
	if platform != cliff_landing:
		return
	player.climb_component.release()
	player.jump_component.ground_elevation = 224.0
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()


func _try_cliff_descent() -> void:
	if (
		cliff_ladder.is_climbable
		and not player.jump_component.is_airborne
		and not player.climb_component.is_elevated()
		and is_equal_approx(player.jump_component.ground_elevation, 224.0)
		and player.position.distance_to(cliff_ladder.position) < 12.0
		and Input.is_action_pressed(&"move_down")
	):
		player.jump_component.ground_elevation = 0.0
		player.climb_component.ground_elevation = 0.0
		player.climb_component.start_descent(cliff_ladder)


func _on_encounter_cleared() -> void:
	super._on_encounter_cleared()
	if _all_encounters_cleared():
		hud.set_stage_name("EXIT: CLIFF DOOR")
