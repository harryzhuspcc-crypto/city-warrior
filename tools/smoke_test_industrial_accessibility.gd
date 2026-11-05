extends "res://tools/smoke_test_industrial_terrain.gd"
## Ordinary right + K inputs, not a hand-picked backwards staircase route.


func _jump_right(stage: PrototypeAlley, height: float) -> void:
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_right")
	var took_off := false
	var landed := false
	for tick: int in range(160):
		await physics_frame
		if stage.player.jump_component.is_airborne:
			took_off = true
		elif took_off:
			landed = is_equal_approx(stage.player.jump_component.ground_elevation, height)
			break
	_release()
	_check(landed, "Right + K reaches height %s at %s (got floor %s)" % [height, stage.player.position, stage.player.jump_component.ground_elevation])


func _walk_right(stage: PrototypeAlley, x: float) -> void:
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return stage.player.position.x >= x, 300), "Walk reaches x=%s (at %s)" % [x, stage.player.position])
	_release()


func _run() -> void:
	var stage := await _new_stage()
	stage.player.set_collision_mask_value(8, false)
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	_check(terrain.landing_depth_assist == 32.0, "Stage 2 opts into forgiving depth landings")
	# The normal starting lane must work without finding a 1-pixel takeoff
	# spot or holding Up before K. Test a range of imperfect depth choices.
	for depth: float in [184.0, 192.0, 200.0]:
		await _place(stage, Vector2(240, depth), 0)
		await _jump_right(stage, 48.0)
		_check(stage.player.position.y <= 176.0, "Landing puts Billy's feet on the actual concrete top")
		await _walk_right(stage, 350)
		await _jump_right(stage, 80.0)
		_check(stage.player.position.x > 400.0, "Normal jump clears the original opening gap")
	# The roof is 128 px above the main girder deck. The old jump apex was
	# only 105 px, forcing an obscure leftwards zigzag through the red steps.
	for x: float in [492.0, 500.0, 508.0]:
		await _place(stage, Vector2(x, 192), 80)
		await _jump_right(stage, 208.0)
		_check(stage.player.position.x >= 560.0, "Roof jump progresses right, never backtracks")
	# Up-right at the stair edge must not let the wider jump slip behind
	# the roof/crate line, where there is no floor to land on.
	for spot: Vector3 in [Vector3(600, 186, 120), Vector3(610, 196, 120), Vector3(590, 186, 136)]:
		await _place(stage, Vector2(spot.x, spot.y), spot.z)
		stage.player.input_component.queue_jump()
		Input.action_press(&"move_right")
		Input.action_press(&"move_up")
		await _frames(70)
		_release()
		_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 90), "Diagonal stair jump finds supported floor")
	_check(stage.player.health_component.current_health == 100, "Forgiving route never costs fall damage")
	_check(terrain.floor_at(384, 192, 48) == null, "Landing assist does not fill the actual pit")
	await AudioSettle.free_level(self, stage)
	_release()
	if failures.is_empty():
		print("INDUSTRIAL_ACCESSIBILITY_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("INDUSTRIAL_ACCESSIBILITY_SMOKE_TEST_FAIL: " + message)
		quit(1)
