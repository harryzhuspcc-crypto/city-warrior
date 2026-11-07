extends SceneTree

const WOODS := preload("res://levels/woods/woods.tscn")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _until(condition: Callable, budget: int = 150) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _new_stage() -> PrototypeAlley:
	var stage := WOODS.instantiate() as PrototypeAlley
	stage.stage_transition.fade_frames = 1
	stage.stage_transition.intro_hold_frames = 1
	stage.set_encounters_enabled(false)
	root.add_child(stage)
	await _until(func() -> bool: return not stage.stage_transition.is_busy(), 10)
	stage.player.set_collision_mask_value(8, false)
	return stage


func _place(stage: PrototypeAlley, point: Vector2) -> void:
	stage.player.position = point
	stage.player.jump_component.ground_elevation = 96.0
	stage.player.jump_component.land_immediately()
	stage.player.terrain_motor.after_move()


func _run() -> void:
	await _test_hole_shapes()
	for sample: Array in [
		[Vector2(704,328), &"move_right", "hole"],
		[Vector2(744,352), &"move_up", "hole"],
		[Vector2(1376,328), &"move_left", "hole"],
		[Vector2(1336,296), &"move_down", "hole"],
		[Vector2(1000,288), &"move_right", "water"],
	]:
		await _test_walk_fall(sample[0], sample[1], sample[2])
	for point: Vector2 in [Vector2(704,328), Vector2(1296,328), Vector2(968,288)]:
		await _test_jump(point)
	await _test_late_jump()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("STAGE_HAZARDS_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("STAGE_HAZARDS_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _test_hole_shapes() -> void:
	var stage := await _new_stage()
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	_check(terrain.pit_lives == 3 and stage.hud.lives_label.text == "LIVES 3", "Stage 3 starts with three visible fall lives")
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = BeltTerrainMap.SUPPORT_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for x: float in [744.0, 1336.0]:
		_check(terrain.floor_at(x,328,96,Rect2(-7,-8,14,8)) == null, "A foot overlapping the rim cannot stand inside hole %s" % x)
		query.position = Vector2(x,232)
		_check(stage.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Physics polygons also subtract hole %s" % x)
		_check(terrain.floor_at(x,304,96) == 96.0 and terrain.floor_at(x,352,96) == 96.0, "Solid ground above/below each small hole is preserved")
	_check(terrain.floor_at(1036,284,96) == null, "Bridge remains broken")
	await AudioSettle.free_level(self,stage)


func _test_walk_fall(origin: Vector2, action: StringName, kind: String) -> void:
	var stage := await _new_stage()
	_place(stage, origin)
	var falls: Array[int] = []
	var impacts: Array[String] = []
	stage.player.terrain_motor.fell_into_pit.connect(func() -> void: falls.append(1))
	stage.player.terrain_motor.pit_impact.connect(func(_point: Vector2, _height: float, impact_kind: String) -> void: impacts.append(impact_kind))
	Input.action_press(action)
	_check(await _until(func() -> bool: return stage.player.terrain_motor.remaining_lives == 2), "Walking %s at %s falls instead of blocking or walking across" % [action,origin])
	Input.action_release(action)
	_check(falls.size() == 1 and impacts == [kind], "Exactly one fall and one %s ripple per crossing" % kind)
	_check(stage.player.health_component.current_health == 100 and stage.state == PrototypeAlley.PLAYING, "Fall uses a life, not HP or immediate game over")
	_check(not stage.player.jump_component.is_airborne and stage.player.position.distance_to(origin) < 48, "Respawn from %s is on the last safe bank/rim (got %s)" % [origin,stage.player.position])
	_check(stage.hud.lives_label.text == "LIVES 2", "HUD reflects the lost life")
	_check(stage.player.visuals.scale == Vector2.ONE and stage.player.visuals.modulate.a > 0, "Recovery restores Billy's visual scale/visibility")
	for tick: int in range(60):
		await physics_frame
	_check(stage.player.terrain_motor.remaining_lives == 2 and falls.size() == 1, "Standing after recovery cannot charge the same fall twice")
	await AudioSettle.free_level(self,stage)


func _test_jump(origin: Vector2) -> void:
	var stage := await _new_stage()
	_place(stage,origin)
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne,10), "K takes off before hazard")
	_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne), "Jump lands beyond hazard")
	Input.action_release(&"move_right")
	_check(stage.player.position.x > origin.x + 85 and stage.player.terrain_motor.remaining_lives == 3, "Jump crosses %s without losing a life" % origin)
	_check(stage.player.health_component.current_health == 100, "Successful jump preserves HP")
	await AudioSettle.free_level(self,stage)


func _test_late_jump() -> void:
	var stage := await _new_stage()
	_place(stage,Vector2(1312,328))
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne,30), "Stepping into a hole starts a fall")
	stage.player.input_component.queue_jump()
	_check(await _until(func() -> bool: return stage.player.jump_component.jump_velocity > 0,8), "Buffered edge jump still rescues a just-started fall")
	_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne), "Late jump lands safely")
	Input.action_release(&"move_right")
	_check(stage.player.terrain_motor.remaining_lives == 3 and stage.player.visuals.scale.is_equal_approx(Vector2.ONE), "Coyote-time jump does not charge a life or leave a shrunk actor (lives %s, scale %s, position %s)" % [stage.player.terrain_motor.remaining_lives,stage.player.visuals.scale,stage.player.position])
	await AudioSettle.free_level(self,stage)
