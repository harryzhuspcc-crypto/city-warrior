extends "res://tools/smoke_test_industrial_terrain.gd"
## Ordinary movement and jumps use the red stairs at the original jump speed.


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
		_check(stage.player.health_component.current_health == 100, "Opening jumps do not cost fall damage at depth %s" % depth)
	_check(stage.player.fighter_stats.jump_takeoff_speed == load("res://features/actors/player/billy_stats.tres").jump_takeoff_speed, "Stage uses its original jump speed, without the high-jump workaround")
	_check(stage.get_node_or_null("WorldGeometry/TopBoundary") == null, "No horizontal wall cuts across the steel platforms")
	await _place(stage, Vector2(500, 128), 80)
	Input.action_press(&"move_up")
	await _frames(50)
	_release()
	_check(stage.player.position.y >= 127.9 and stage.player.position.y <= 128.1 and not stage.player.jump_component.is_airborne, "Up meets the selected girder rear wall with room for the feet")
	# These raised tops overlap the girder's support polygon. The old
	# floor-only check let Billy walk straight through their vertical faces.
	await _place(stage, Vector2(420, 140), 80)
	Input.action_press(&"move_right")
	await _frames(35)
	_release()
	_check(stage.player.position.x <= 433.1, "Red step face blocks walking even with lower floor underneath")
	_check(stage.player.jump_component.ground_elevation == 80.0, "Walking into a tall face never teleports Billy up")
	await _place(stage, Vector2(420, 140), 80)
	await _jump_right(stage, 104.0) # Marked platform 1.
	await _walk_right(stage, 500)
	await _jump_right(stage, 152.0) # Marked platform 2.
	await _jump_right(stage, 192.0) # Main deck.
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
