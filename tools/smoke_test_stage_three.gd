extends SceneTree

const WOODS := preload("res://levels/woods/woods.tscn")
const YARD := preload("res://levels/industrial_yard/industrial_yard.tscn")
const WOODS_PATH := "res://levels/woods/woods.tscn"
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_until(condition: Callable, budget: int = 120) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _run() -> void:
	await _test_shapes_and_route()
	await _test_pits_and_edges()
	await _test_transition_and_restart()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("STAGE_THREE_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("STAGE_THREE_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _walk(stage: PrototypeAlley, destination: Vector2, budget: int = 900) -> void:
	for tick: int in range(budget):
		var difference := destination - stage.player.position
		if absf(difference.x) <= 1.6 and absf(difference.y) <= 1.0:
			_release_inputs()
			return
		for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
			Input.action_release(action)
		if absf(difference.x) > 1.6:
			Input.action_press(&"move_right" if difference.x > 0 else &"move_left")
		if absf(difference.y) > 1.0:
			Input.action_press(&"move_down" if difference.y > 0 else &"move_up")
		await physics_frame
	_check(false, "Route reaches %s (got %s, floor %s)" % [destination, stage.player.position, stage.player.jump_component.ground_elevation])
	_release_inputs()


func _release_inputs() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _jump_right(stage: PrototypeAlley, floor_height: float) -> void:
	_release_inputs()
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_right")
	var took_off := false
	var landed := false
	for tick: int in range(160):
		await physics_frame
		if stage.player.jump_component.is_airborne:
			took_off = true
		elif took_off:
			landed = is_equal_approx(stage.player.jump_component.ground_elevation, floor_height)
			break
	_release_inputs()
	_check(landed, "Jump lands on floor %s at %s (got %s)" % [floor_height, stage.player.position, stage.player.jump_component.ground_elevation])


func _test_shapes_and_route() -> void:
	var stage := WOODS.instantiate() as PrototypeAlley
	root.add_child(stage)
	await physics_frame
	_check(stage.hud.message_label.text.contains("STAGE 3"), "Woods intro title")
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Woods intro releases controls")
	_check(stage.music.loops() and stage.music.stream.resource_path.ends_with("07_woods.mp3"), "Woods music loops")
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	var source := Image.new()
	_check(source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/source_sheets/new-york-20xx.png")) == OK, "Source PNG decodes")
	source.convert(Image.FORMAT_RGBA8)
	var expected := source.get_region(Rect2i(2288, 240, 2928, 496))
	var picture := Image.new()
	_check(picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stages/woods.png")) == OK, "Stage 3 PNG decodes")
	picture.convert(Image.FORMAT_RGBA8)
	_check(expected.get_data() == picture.get_data(), "Every Stage 3 RGBA pixel matches original source")
	_check(terrain.surfaces.size() == 8 and terrain.get_child_count() == 10, "Eight fresh support polygons and two solid boundaries")
	for surface: Dictionary in terrain.surfaces:
		var area := terrain.get_node(String(surface["name"])) as Area2D
		_check(area != null and area.collision_layer == BeltTerrainMap.SUPPORT_LAYER, "Surface registered on physics support layer")
		var shape := area.get_child(0) as CollisionPolygon2D
		_check(shape != null and shape.polygon.size() >= 4 and shape.scale == Vector2.ONE, "Assigned unscaled collision polygon")
	var query := PhysicsPointQueryParameters2D.new()
	query.position = Vector2(960, 188)
	query.collision_mask = BeltTerrainMap.SUPPORT_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	_check(not stage.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Physics server sees original wooden bridge")
	query.position = Vector2(1036, 188)
	_check(stage.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Broken bridge has a real gap, not a hidden floor")
	_check(terrain.floor_at(1036, 284, 96) == null, "Support agrees with bridge gap")
	_check(terrain.floor_at(2250, 304) == 0.0 and terrain.floor_at(2784, 304) == 224.0, "Lower deck and cliff terrace have separate heights")
	_check(not stage.stage_transition.has_next_stage(), "Stage 3 remains terminal until a further stage exists")
	# No encounter bypass: every wave really triggers/spawns/clears while Billy
	# walks. Only the enemies' fighting is replaced by deterministic removal.
	var spawned: Array[StringName] = []
	for encounter: EncounterController in stage.encounter_controllers():
		encounter.enemy_spawned.connect(func(enemy: Node2D) -> void:
			spawned.append(encounter.name)
			var height := float(encounter.get_meta(&"terrain_height", 96.0))
			_check(terrain.floor_at(enemy.position.x, enemy.position.y, height) == height, "Wave spawns on its drawn floor")
			enemy.set_physics_process(false)
			enemy.queue_free()
		)
	await _walk(stage, Vector2(968, 288))
	await _jump_right(stage, 96.0)
	_check(stage.player.position.x > 1056, "Jump crosses the actual missing bridge planks")
	await _walk(stage, Vector2(1220, 288))
	await _walk(stage, Vector2(1720, 320))
	await _walk(stage, Vector2(2110, 304))
	await _jump_right(stage, 0.0)
	await _walk(stage, Vector2(2500, 304))
	_release_inputs()
	Input.action_press(&"move_up")
	_check(await _wait_until(func() -> bool: return stage.player.climb_component.is_climbing, 20), "Visible cliff handholds can be grabbed")
	_check(await _wait_until(func() -> bool: return is_equal_approx(stage.player.jump_component.ground_elevation, 224.0) and not stage.player.climb_component.is_elevated(), 340), "Cliff climb hands off to normal terrace combat")
	_release_inputs()
	_check(not stage.player.hurtbox.is_invulnerable, "Cliff landing restores vulnerability")
	# Verify both directions before the boss locks this optional backtrack.
	Input.action_press(&"move_down")
	_check(await _wait_until(func() -> bool: return stage.player.climb_component.is_climbing, 20), "Down re-enters the cliff ladder")
	_check(await _wait_until(func() -> bool: return not stage.player.climb_component.is_elevated(), 340), "Cliff descent reaches steel deck")
	_release_inputs()
	Input.action_press(&"move_up")
	_check(await _wait_until(func() -> bool: return stage.player.climb_component.is_climbing, 20), "Cliff can be climbed again")
	_check(await _wait_until(func() -> bool: return is_equal_approx(stage.player.jump_component.ground_elevation, 224.0) and not stage.player.climb_component.is_elevated(), 340), "Second climb returns to terrace")
	_release_inputs()
	await _walk(stage, Vector2(2792, 304))
	_check(stage.state == PrototypeAlley.PLAYING, "Passing the exit x is not enough to clear")
	await _walk(stage, stage.exit.position)
	_release_inputs()
	_check(await _wait_until(func() -> bool: return stage.state == PrototypeAlley.CLEARED, 20), "All waves and the cliff door clear Stage 3")
	_check(spawned.size() == 11 and stage._all_encounters_cleared(), "All eleven enemies spawned across four sequential arenas")
	_check(stage.player.health_component.current_health == 100, "Full original woods/bridge/cliff route takes no fall damage")
	_check(await _wait_until(func() -> bool: return stage.hud.message_label.text.contains("PRESS J TO RESTART")), "Terminal woods clear offers replay")
	await AudioSettle.free_level(self, stage)


func _test_pits_and_edges() -> void:
	var stage := WOODS.instantiate() as PrototypeAlley
	root.add_child(stage)
	await physics_frame
	_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy()), "Pit fixture intro")
	stage.set_encounters_enabled(false)
	# A lower supported deck behind a rear wall must not trick the motor into
	# stepping down through the terrace. This also tests held Up after a climb.
	stage.player.position = Vector2(2500, 304)
	stage.player.jump_component.ground_elevation = 224.0
	stage.player.jump_component.land_immediately()
	Input.action_press(&"move_up")
	for tick: int in range(24):
		await physics_frame
	_release_inputs()
	_check(is_equal_approx(stage.player.jump_component.ground_elevation, 224.0) and not stage.player.jump_component.is_airborne, "Held Up cannot fall backwards through the terrace onto the lower steel deck")
	stage.player.position = Vector2(1036, 284)
	stage.player.jump_component.ground_elevation = 96.0
	stage.player.jump_component.land_immediately()
	_check(await _wait_until(func() -> bool: return stage.player.jump_component.is_airborne, 10), "Unsupported feet fall through actual missing bridge planks")
	_check(await _wait_until(func() -> bool: return stage.player.health_component.current_health == 80, 100), "River fall costs exactly 20 HP")
	_check(stage.player.position.x < 784 and not stage.player.jump_component.is_airborne, "River recovery returns to supported bank")
	_check(stage.player.hurtbox.is_invulnerable, "Recovery grants temporary protection")
	_check(await _wait_until(func() -> bool: return not stage.player.hurtbox.is_invulnerable, 60), "Recovery protection expires")
	stage.player.health_component.take_damage(60)
	stage.player.position = Vector2(1036, 284)
	stage.player.jump_component.ground_elevation = 96.0
	stage.player.jump_component.land_immediately()
	_check(await _wait_until(func() -> bool: return stage.state == PrototypeAlley.DEFEATED, 100), "Lethal Stage 3 fall uses normal defeat flow")
	await AudioSettle.free_level(self, stage)


func _test_transition_and_restart() -> void:
	var yard := YARD.instantiate() as PrototypeAlley
	root.add_child(yard)
	current_scene = yard
	await physics_frame
	_check(await _wait_until(func() -> bool: return not yard.stage_transition.is_busy()), "Yard transition fixture intro")
	yard.set_encounters_enabled(false)
	yard.player.position = yard.exit.position
	yard.player.jump_component.ground_elevation = 208.0
	yard.player.jump_component.land_immediately()
	yard.stage_transition.clear_hold_frames = 2
	yard.stage_transition.walk_frames = 2
	yard.stage_transition.fade_frames = 2
	var yard_id := yard.get_instance_id()
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == WOODS_PATH, 30), "Real Stage 2 to Stage 3 scene replacement")
	_check(instance_from_id(yard_id) == null, "Industrial actors freed on transition")
	if current_scene == null or current_scene.scene_file_path != WOODS_PATH:
		if current_scene != null:
			var broken := current_scene
			current_scene = null
			await AudioSettle.free_level(self, broken)
		return
	var woods := current_scene as PrototypeAlley
	_check(woods.player.position == Vector2(56, 288) and woods.player.health_component.current_health == 100, "Stage 3 gets fresh entry and health")
	_check(await _wait_until(func() -> bool: return not woods.stage_transition.is_busy()), "Stage 3 scene-swap intro completes")
	woods.player.position = woods.exit.position
	await physics_frame
	_check(woods.state == PrototypeAlley.PLAYING, "Uncleared encounters prevent early Stage 3 clear")
	woods.player.health_component.take_damage(999)
	_check(await _wait_until(func() -> bool: return woods._restart_armed), "Stage 3 defeat offers restart")
	var woods_id := woods.get_instance_id()
	woods.request_restart()
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != woods_id, 20), "Stage 3 actually reloads")
	var fresh := current_scene as PrototypeAlley
	_check(fresh.scene_file_path == WOODS_PATH and fresh.player.health_component.current_health == 100, "Replay reloads woods, not Stage 1")
	current_scene = null
	await AudioSettle.free_level(self, fresh)
