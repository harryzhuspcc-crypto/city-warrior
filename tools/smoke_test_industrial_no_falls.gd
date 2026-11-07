extends "res://tools/smoke_test_industrial_terrain.gd"
## Past the opening gap Stage 2 has no pits: real walks and jumps from every
## red girder, step, tower and roof edge stay on the map.


func _run() -> void:
	var stage := await _new_stage()
	var player := stage.player
	# Isolate map support from screen-edge walls when moving the fixture.
	player.set_collision_mask_value(8, false)
	var falls: Array[int] = []
	player.terrain_motor.fell_into_pit.connect(func() -> void: falls.append(1))
	# Past the opening gap nothing is a pit: walking or jumping off any red
	# girder, step, tower or roof edge is held back by that edge instead.
	var edge_spots: Array[Vector3] = [
		Vector3(500, 128, 80), Vector3(426, 176, 80), Vector3(426, 204, 80),
		Vector3(570, 174, 96), Vector3(480, 156, 128), Vector3(550, 160, 176),
		Vector3(585, 166, 160), Vector3(560, 164, 176),
		Vector3(575, 172, 208), Vector3(720, 229, 208), Vector3(985, 226, 208),
	]
	var directions: Array = [
		[&"move_right"], [&"move_left"], [&"move_down"],
		[&"move_right", &"move_down"], [&"move_right", &"move_up"],
	]
	var pit_spots: Array[String] = []
	for spot: Vector3 in edge_spots:
		for held: Array in directions:
			for jumping: bool in [false, true]:
				await _place(stage, Vector2(spot.x, spot.y), spot.z)
				var falls_before := falls.size()
				if jumping:
					player.input_component.queue_jump()
				for action: StringName in held:
					Input.action_press(action)
				await _frames(70)
				_release()
				await _until(func() -> bool: return not player.jump_component.is_airborne, 60)
				if falls.size() != falls_before:
					pit_spots.append("%s %s%s" % [spot, held, " +jump" if jumping else ""])
	_check(pit_spots.is_empty(), "No pit falls past the opening gap: %s" % [pit_spots])
	_check(player.health_component.current_health == 100, "Edge sweep never costs fall damage")
	await AudioSettle.free_level(self, stage)
	_release()
	if failures.is_empty():
		print("INDUSTRIAL_NO_FALLS_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("INDUSTRIAL_NO_FALLS_SMOKE_TEST_FAIL: " + message)
		quit(1)
