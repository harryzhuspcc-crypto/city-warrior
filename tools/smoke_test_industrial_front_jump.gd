extends "res://tools/smoke_test_industrial_terrain.gd"
## Front approach to the second steel stack, with real camera walls enabled.

func _run() -> void:
	var stage := await _new_stage()
	# Reach the front approach by walking across the first stage, not teleporting.
	await _place(stage, Vector2(488, 144), 104)
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.position.x >= 510, 50), "Walk across first steel top (at %s)" % stage.player.position)
	_release()
	# Follow the pictured diagonal seam around the taller tower's left face.
	Input.action_press(&"move_down")
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.position.y >= 172, 60), "Diagonal seam reaches front steel section")
	_release()
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.position.x >= 568, 60), "Walk in front of second steel face")
	_release()
	_check(not stage.player.jump_component.is_airborne and stage.player.jump_component.ground_elevation == 104, "Walking the first steel stage never drops to the girder underneath")
	for point: Vector2 in [Vector2(552, 168), Vector2(568, 172), Vector2(580, 176)]:
		await _place(stage, point, 104)
		_check(not stage.player.jump_component.is_airborne and stage.player.jump_component.ground_elevation == 104, "Front of first steel stage supports Billy at %s" % point)
		Input.action_press(&"move_up")
		await _frames(25)
		_release()
		_check(stage.player.position.y >= 167.9 and stage.player.jump_component.ground_elevation == 104, "Second steel front face blocks walking from %s (at %s floor %s)" % [point, stage.player.position, stage.player.jump_component.ground_elevation])
		var key := InputEventKey.new()
		key.physical_keycode = KEY_K
		key.pressed = true
		Input.parse_input_event(key)
		Input.action_press(&"move_up")
		_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "K starts front jump")
		key = InputEventKey.new()
		key.physical_keycode = KEY_K
		key.pressed = false
		Input.parse_input_event(key)
		_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Front jump lands")
		_release()
		_check(stage.player.jump_component.ground_elevation == 152, "Up + K reaches second steel stage from %s (got %s at %s)" % [point, stage.player.jump_component.ground_elevation, stage.player.position])
	await AudioSettle.free_level(self, stage)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("INDUSTRIAL_FRONT_JUMP_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
