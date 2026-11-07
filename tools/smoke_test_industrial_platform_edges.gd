extends "res://tools/smoke_test_industrial_terrain.gd"
## Real movement regression: even the lowest steel step needs a jump;
## walking off its front edge falls onto the girder beneath it.


func _run() -> void:
	var stage := await _new_stage()
	var player := stage.player
	player.set_collision_mask_value(8, false)
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	_check(terrain.step_height == 0.0, "Industrial platforms require jumping for every rise")
	var step_wall := terrain.get_node("Step1Blocker") as StaticBody2D
	terrain.sync_platform_collisions(player, 80.0, terrain.step_height, false)
	_check(not player.get_collision_exceptions().has(step_wall), "The front steel section remains solid below its top")
	terrain.sync_platform_collisions(player, 104.0, 0.0, false)
	_check(player.get_collision_exceptions().has(step_wall), "The front steel section clears once the feet reach its top")
	await _place(stage, Vector2(420, 140), 80)
	Input.action_press(&"move_right")
	await _frames(24)
	_release()
	_check(player.position.x <= 433.1 and player.jump_component.ground_elevation == 80.0, "Walking into steel stays below its top")
	player.input_component.queue_jump()
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 10), "Jump leaves the girder")
	_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 100), "Jump lands on steel")
	_release()
	_check(player.jump_component.ground_elevation == 104.0, "Jump reaches the raised steel landing")
	await _place(stage, Vector2(470, 148), 104)
	Input.action_press(&"move_down")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 24), "Walking off the front edge starts a fall")
	_release()
	_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 80), "Fall lands on the lower girder")
	_check(player.jump_component.ground_elevation == 80.0, "Lower girder catches the fall instead of snapping to the upper edge")
	_check(player.health_component.current_health == 100, "Landing on the lower iron sheet is not a pit death")
	# High steel landing has a lower girder to its left. It must not retain
	# the old invisible wall or teleport instantly down twenty-four pixels.
	await _place(stage, Vector2(480, 140), 104)
	Input.action_press(&"move_left")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 65), "Walking off a tall steel side starts a fall")
	_release()
	_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 100), "Tall steel fall settles")
	_check(player.jump_component.ground_elevation == 80.0, "Tall steel fall reaches the lower girder")
	_check(player.health_component.current_health == 100, "Tall steel drop onto a supported floor preserves health")
	await AudioSettle.free_level(self, stage)
	_release()
	if failures.is_empty():
		print("INDUSTRIAL_PLATFORM_EDGES_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("INDUSTRIAL_PLATFORM_EDGES_SMOKE_TEST_FAIL: " + message)
		quit(1)
