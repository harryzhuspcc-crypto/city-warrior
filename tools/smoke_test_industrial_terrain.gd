extends SceneTree

const YARD := preload("res://levels/industrial_yard/industrial_yard.tscn")
const WILLIAMS := preload("res://features/actors/enemies/williams/williams.tscn")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _frames(count: int) -> void:
	for tick: int in range(count):
		await physics_frame


func _until(condition: Callable, budget: int) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _new_stage() -> PrototypeAlley:
	var stage := YARD.instantiate() as PrototypeAlley
	root.add_child(stage)
	stage.set_encounters_enabled(false)
	await _until(func() -> bool: return not stage.stage_transition.is_busy(), 100)
	return stage


func _place(stage: PrototypeAlley, point: Vector2, height: float) -> void:
	_release()
	var player := stage.player
	player.climb_component.release()
	player.combat_component.cancel_attack()
	player.hit_reaction_component.reset()
	player.input_component.clear_buffered_actions()
	player.position = point
	player.velocity = Vector2.ZERO
	player.jump_component.ground_elevation = height
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()
	await _frames(2)


func _run() -> void:
	_test_exact_original_pixels()
	await _test_traced_shapes_and_back_wall()
	await _test_native_conveyor_and_crates()
	await _test_both_native_ladders()
	await _test_falls_and_defeat()
	_release()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("INDUSTRIAL_TERRAIN_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("INDUSTRIAL_TERRAIN_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _test_exact_original_pixels() -> void:
	var original := Image.new()
	var picture := Image.new()
	_check(original.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/source_sheets/new-york-20xx.png")) == OK, "Source PNG decodes")
	_check(picture.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/stages/industrial_yard.png")) == OK, "Stage PNG decodes")
	original = original.get_region(Rect2i(1232, 0, 1056, 576))
	original.convert(Image.FORMAT_RGBA8)
	picture.convert(Image.FORMAT_RGBA8)
	_check(original.get_data() == picture.get_data(), "Every RGBA pixel equals the original industrial picture; no repainted floors, overlays or omitted lower yard")


func _test_traced_shapes_and_back_wall() -> void:
	var stage := await _new_stage()
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	_check(terrain.surfaces.size() == 17, "Original platforms plus six separately traced crate tops are authored")
	for surface: Dictionary in terrain.surfaces:
		var name := String(surface["name"])
		var area := terrain.get_node(name) as Area2D
		var collision := area.get_node("SurfaceCollision") as CollisionPolygon2D
		var center := Vector2.ZERO
		for index: int in range(surface["polygon"].size()):
			var point: Array = surface["polygon"][index]
			var expected := Vector2(float(point[0]), float(point[1]) - 264.0)
			_check(collision.polygon[index] == expected, name + " collision is traced in native picture coordinates")
			center += expected
		center /= float(collision.polygon.size())
		var height := float(surface["height"])
		var floor: Variant = terrain.floor_at(center.x, center.y + height, height)
		_check(floor != null and is_equal_approx(float(floor), height), name + " support agrees with collision shape")
		var query := PhysicsPointQueryParameters2D.new()
		query.position = center
		query.collision_mask = BeltTerrainMap.SUPPORT_LAYER
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var found := false
		for hit: Dictionary in stage.get_world_2d().direct_space_state.intersect_point(query, 32):
			if hit["collider"] == area:
				found = true
		_check(found, name + " has a real physics-server CollisionPolygon2D")
		if surface.get("solid", false):
			query.position = center + Vector2(0, height)
			query.collision_mask = BeltTerrainMap.PLATFORM_WALL_LAYER
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var wall := terrain.get_node(name + "Blocker") as StaticBody2D
			found = false
			for hit: Dictionary in stage.get_world_2d().direct_space_state.intersect_point(query, 32):
				found = found or hit["collider"] == wall
			_check(found, name + " has a solid raised-face footprint in the physics server")
	var player := stage.player
	player.set_physics_process(false)
	var saved_mask := player.collision_mask
	var transform := player.global_transform
	transform.origin = Vector2(420, 140)
	terrain.sync_platform_collisions(player, 80.0, 18.0, false)
	player.collision_mask = BeltTerrainMap.PLATFORM_WALL_LAYER
	_check(player.test_move(transform, Vector2(60, 0)), "Actual steel blocker stops a lower fighter even where girder support overlaps")
	terrain.sync_platform_collisions(player, 104.0, 0.5, false)
	_check(not player.test_move(transform, Vector2(60, 0)), "The same steel blocker permits a fighter who clears its top")
	player.collision_mask = saved_mask
	player.set_physics_process(true)
	_check(terrain.floor_at(368, 192, 80) == null, "The original dark gap is unsupported, not covered with an invented street")
	_check(terrain.floor_at(1008, 192, 192) != 192.0, "The roof stops at its visible slanted edge")
	await _place(stage, Vector2(96, 160), 0)
	Input.action_press(&"move_up")
	await _frames(50)
	_release()
	_check(stage.player.position.y >= 136 and not stage.player.jump_component.is_airborne, "Gate wall stops backward depth movement instead of falling through the background")
	Input.action_press(&"move_up")
	Input.action_press(&"move_right")
	await _frames(20)
	_release()
	_check(stage.player.position.x > 110 and stage.player.position.y >= 136, "Diagonal movement slides along the picture's back wall instead of sticking on both axes")
	await _place(stage, Vector2(720, 208), 192)
	Input.action_press(&"move_down")
	await _frames(7)
	_release()
	_check(stage.player.terrain_motor.checkpoint.y <= 208.01, "Depth-edge checkpoints retain room for the entire foot instead of saving the front roof lip")
	await AudioSettle.free_level(self, stage)


func _test_native_conveyor_and_crates() -> void:
	var stage := await _new_stage()
	var player := stage.player
	await _place(stage, Vector2(880, 176), 208)
	var start := player.position.x
	await _frames(30)
	_check(absf(player.position.x - start - 12.0) < 1.0, "Only the original small blue conveyor carries an idle fighter at 24 px/s")
	_check(is_equal_approx(player.jump_component.ground_elevation, 208), "Conveyor top is sixteen pixels above the actual roof")
	Input.action_press(&"move_left")
	start = player.position.x
	await _frames(15)
	_release()
	_check(absf(player.position.x - start + 16.5) < 2.0, "Walking against the native conveyor combines fighter and belt velocity")
	player.input_component.queue_jump()
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 10), "Jump starts on native conveyor")
	start = player.position.x
	await _frames(12)
	_check(absf(player.position.x - start) < 0.5, "Belt does not drag fighters through the air")
	await _place(stage, Vector2(704, 152), 192)
	Input.action_press(&"move_left")
	await _frames(40)
	_release()
	_check(player.position.x >= 694.0 and player.position.x <= 704.0, "Real crate footprint collision stops Billy at the pictured crate edge")
	_check(not player.jump_component.is_airborne, "Crate collision leaves Billy on the roof")
	await AudioSettle.free_level(self, stage)


func _test_both_native_ladders() -> void:
	var stage := await _new_stage()
	var player := stage.player
	await _place(stage, Vector2(736, 152), 192)
	Input.action_press(&"move_up")
	_check(await _until(func() -> bool: return is_equal_approx(player.jump_component.ground_elevation, 320) and not player.climb_component.is_elevated(), 190), "Actual upper ladder reaches its pictured awning")
	_release()
	_check(is_equal_approx(player.combat_elevation(), 320), "Awning height includes the roof below, not just the ladder length")
	_check(is_equal_approx(player.visuals.position.y, -360), "Feet line up with original awning at picture y=96")
	Input.action_press(&"move_down")
	_check(await _until(func() -> bool: return player.climb_component.is_climbing, 30), "Awning descent starts from its walkable terrain top")
	_check(await _until(func() -> bool: return not player.climb_component.is_elevated(), 190), "Upper ladder descends back onto the roof")
	_release()
	_check(is_equal_approx(player.jump_component.ground_elevation, 192), "Awning descent retains the loading roof as its floor")
	await _place(stage, Vector2(888, 216), 192)
	Input.action_press(&"move_down")
	_check(await _until(func() -> bool: return player.climb_component.is_climbing, 8), "Down enters the pictured front ladder from the roof edge")
	_check(await _until(func() -> bool: return not player.climb_component.is_elevated(), 290), "Front ladder reaches the original lower yard")
	_release()
	_check(is_zero_approx(player.jump_component.ground_elevation), "Lower yard is a real ground floor")
	_check(player.health_component.current_health == 100, "Descending the front ladder is not a pit fall")
	Input.action_press(&"move_up")
	_check(await _until(func() -> bool: return is_equal_approx(player.jump_component.ground_elevation, 192) and not player.climb_component.is_elevated(), 290), "Front ladder returns control to ordinary rooftop fighting, not an invulnerable decorative ledge")
	_release()
	_check(not player.hurtbox.is_invulnerable, "Front ladder handoff restores normal vulnerability")
	await AudioSettle.free_level(self, stage)


func _test_falls_and_defeat() -> void:
	var stage := await _new_stage()
	var player := stage.player
	await _place(stage, Vector2(720, 192), 192)
	player.terrain_motor.checkpoint = player.position
	player.position = Vector2(1040, 208)
	player.terrain_motor.after_move()
	_check(await _until(func() -> bool: return player.terrain_motor.remaining_lives == 2, 130), "Falling past the actual roof lip costs one life")
	_check(player.position.distance_to(Vector2(720, 192)) < 1.0, "Recovery returns to supported original artwork")
	_check(player.hurtbox.is_invulnerable, "Recovery grants temporary protection")
	await _frames(55)
	_check(not player.hurtbox.is_invulnerable and player.health_component.current_health == 100 and player.terrain_motor.remaining_lives == 2, "Recovery does not repeat the fall or leave permanent invulnerability")
	# A checkpoint can belong to a higher floor than the most recent launch.
	# Recovery must retain that floor, not resample with the lower fall's ceiling.
	player.jump_component.ground_elevation = 0.0
	player.position = Vector2(1040, 208)
	player.terrain_motor.after_move()
	_check(await _until(func() -> bool: return player.terrain_motor.remaining_lives == 1, 130), "A fall from a lower floor still recovers to the saved rooftop checkpoint")
	_check(is_equal_approx(player.jump_component.ground_elevation, 192), "Checkpoint stores elevation as well as x/depth")
	var enemy := WILLIAMS.instantiate() as EnemyFighter
	enemy.position = Vector2(1040, 208)
	enemy.set_meta(&"terrain_height", 192.0)
	enemy.death_linger_frames = 0
	stage.actors.add_child(enemy)
	(stage.get_node("Terrain") as BeltTerrainMap).attach_actor(enemy)
	var reports: Array[int] = []
	enemy.defeated.connect(func() -> void: reports.append(1))
	var enemy_ref: WeakRef = weakref(enemy)
	_check(await _until(func() -> bool: return enemy_ref.get_ref() == null, 130), "Enemies also fall outside the traced deck")
	_check(reports.size() == 1, "Enemy pit death reports exactly once even with zero death linger")
	_check(player.health_component.current_health == 100, "Surviving pit recovery spends lives, not health")
	player.position = Vector2(1040, 208)
	player.terrain_motor.after_move()
	_check(await _until(func() -> bool: return stage.state == PrototypeAlley.DEFEATED, 130), "Fatal falls use normal defeat/restart flow")
	await AudioSettle.free_level(self, stage)
