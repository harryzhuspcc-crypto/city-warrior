extends PrototypeAlley

@export var terrain: BeltTerrainMap
@export var enemy_encounters_enabled: bool = true

@onready var collision_outlines: Node2D = $PlatformBlocks/CollisionOutlines


func _ready() -> void:
	super._ready()
	collision_outlines.hide()
	set_encounters_enabled(enemy_encounters_enabled)
	terrain.attach_actor(player)
	hud.set_lives(player.terrain_motor.remaining_lives)
	player.terrain_motor.lives_changed.connect(hud.set_lives)
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
			and absf(player.combat_elevation() - 192.0) < 1.0
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
	var height := 192.0
	if platform == get_node("Awning"):
		height = 320.0
	elif platform != get_node("FrontRoofLanding"):
		return
	player.climb_component.release()
	player.jump_component.ground_elevation = height
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()


func _try_front_ladder_descent() -> void:
	if player.jump_component.is_airborne or player.climb_component.is_elevated() or not Input.is_action_pressed(&"move_down"):
		return
	for ladder_name: String in ["FrontLadder", "AwningLadder"]:
		var ladder := get_node("Ladders/" + ladder_name) as Ladder
		var top := ladder.base_elevation + ladder.top_height()
		if is_equal_approx(player.combat_elevation(), top) and player.position.distance_to(ladder.position) < 12.0:
			player.jump_component.ground_elevation = ladder.base_elevation
			player.climb_component.ground_elevation = ladder.base_elevation
			player.climb_component.start_descent(ladder)
			return


func _on_encounter_cleared() -> void:
	super._on_encounter_cleared()
	if _all_encounters_cleared():
		hud.set_stage_name("EXIT: GREEN DOOR")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		collision_outlines.visible = not collision_outlines.visible
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
