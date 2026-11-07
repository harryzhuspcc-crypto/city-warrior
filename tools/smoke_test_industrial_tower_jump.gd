extends "res://tools/smoke_test_industrial_terrain.gd"
## Ordinary rightward jumps from the pictured lower steel platform.

func _run() -> void:
	var stage := await _new_stage()
	for point: Vector2 in [Vector2(465, 140), Vector2(480, 144), Vector2(500, 140), Vector2(500, 148), Vector2(520, 156), Vector2(520, 164)]:
		await _place(stage, point, 104)
		var start_height := stage.player.jump_component.ground_elevation
		_check(not stage.player.jump_component.is_airborne and start_height == 104, "Visible lower steel top supports Billy at %s" % point)
		stage.player.input_component.queue_jump()
		Input.action_press(&"move_right")
		_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "Tower jump starts")
		_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Tower jump lands")
		_release()
		_check(stage.player.jump_component.ground_elevation == 152, "Jump from %s (floor %s) reaches tower top: landed %s at %s" % [point, start_height, stage.player.jump_component.ground_elevation, stage.player.position])
		# Continue from the tower onto the factory deck using the same controls.
		stage.player.input_component.queue_jump()
		Input.action_press(&"move_right")
		_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "Deck jump starts")
		_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Deck jump lands")
		_release()
		_check(stage.player.jump_component.ground_elevation == 192, "Tower-to-deck jump succeeds from depth %s" % point.y)
	# Actual K input after walking flush against the left blocker.
	for depth: float in [136, 140, 148]:
		await _place(stage, Vector2(500, depth), 128)
		Input.action_press(&"move_right")
		await _frames(30)
		_check(stage.player.jump_component.ground_elevation == 104 and not stage.player.jump_component.is_airborne, "Left blocker stops walking before K")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_K
		key.pressed = true
		Input.parse_input_event(key)
		_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "K starts jump against left face")
		key = InputEventKey.new()
		key.physical_keycode = KEY_K
		key.pressed = false
		Input.parse_input_event(key)
		_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Left-face jump lands")
		_release()
		_check(stage.player.jump_component.ground_elevation == 152, "K against left face reaches tower at depth %s (got %s at %s)" % [depth, stage.player.jump_component.ground_elevation, stage.player.position])
	# A jump too far right meets the taller factory face; assist must not
	# pull Billy through that wall to reach the tower behind it.
	await _place(stage, Vector2(536, 172), 104)
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "Corner safety jump starts")
	_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Corner safety jump lands")
	_release()
	_check(stage.player.jump_component.ground_elevation == 104, "Landing assistance does not bypass the taller factory blocker")
	await AudioSettle.free_level(self, stage)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("INDUSTRIAL_TOWER_JUMP_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
