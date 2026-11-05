extends "res://tools/smoke_test_industrial_terrain.gd"
## Regressions for the playable opening, not just polygon-centre queries.


func _run() -> void:
	var stage := await _new_stage()
	var player := stage.player
	# Isolate map support from screen-edge walls when moving the fixture
	# between samples; ordinary world/platform collisions remain enabled.
	player.set_collision_mask_value(8, false)
	var falls: Array[int] = []
	player.terrain_motor.fell_into_pit.connect(func() -> void: falls.append(1))
	# The old trace omitted the right-hand strip of the concrete block.
	for point: Vector2 in [Vector2(350, 156), Vector2(358, 160), Vector2(360, 168)]:
		await _place(stage, point, 48)
		await _frames(8)
		_check(not player.jump_component.is_airborne, "Concrete path stays supported at %s" % point)
		_check(is_equal_approx(player.jump_component.ground_elevation, 48), "Concrete path retains its floor height")
	# A foot still on the sloping girder top must not become a pit fall just
	# because the actor's origin is a few pixels beyond the polygon edge.
	for point: Vector2 in [Vector2(404, 192), Vector2(450, 204)]:
		await _place(stage, point, 80)
		await _frames(8)
		_check(not player.jump_component.is_airborne, "Girder path supports the whole foot at %s" % point)
	await _place(stage, Vector2(350, 156), 48)
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	for tick: int in range(16):
		await physics_frame
		_check(not player.jump_component.is_airborne, "Walking along the concrete's slanted edge stays supported")
	_release()
	await _place(stage, Vector2(358, 160), 48)
	player.input_component.queue_jump()
	Input.action_press(&"move_right")
	var took_off := false
	var landed := false
	for tick: int in range(120):
		await physics_frame
		if player.jump_component.is_airborne:
			took_off = true
		elif took_off:
			landed = is_equal_approx(player.jump_component.ground_elevation, 80)
			break
	_release()
	_check(landed, "A buffered jump from the block's actual right edge lands on the girder path")
	# Opening grates are artwork on solid road; the bottom of this road is a
	# map boundary, not a death pit leading to the lower yard on the far right.
	await _place(stage, Vector2(96, 192), 0)
	Input.action_press(&"move_down")
	await _frames(35)
	_release()
	_check(player.position.y <= 216.1, "Opening street stops at its drawn lower boundary")
	_check(not player.jump_component.is_airborne, "Following the opening road does not fall off the cropped map")
	await _place(stage, Vector2(224, 208), 0)
	await _frames(10)
	_check(not player.jump_component.is_airborne, "Second opening grate is solid walking surface")
	# The road and rubble run right up to the block's base. Walking along it
	# and jumping from against the block's front face must land on top.
	await _place(stage, Vector2(250, 192), 0)
	Input.action_press(&"move_right")
	for tick: int in range(120):
		if player.position.x >= 336.0 or player.jump_component.is_airborne:
			break
		await physics_frame
	_release()
	_check(not player.jump_component.is_airborne and player.position.x >= 336.0, "Rubble in front of the block is solid ground (at %s)" % player.position)
	Input.action_press(&"move_up")
	await _frames(40)
	_release()
	_check(not player.jump_component.is_airborne and player.position.y <= 169.0, "The block's front face stops walking at its base (at %s)" % player.position)
	player.input_component.queue_jump()
	var reached_top := false
	for tick: int in range(120):
		await physics_frame
		if not player.jump_component.is_airborne and is_equal_approx(player.jump_component.ground_elevation, 48):
			reached_top = true
			break
	_check(reached_top, "A straight jump from the block's base lands on the concrete top")
	# Recorded playtest: walking right off the red steps towards the olive
	# roof and pressing K a moment late must still jump from that edge.
	await _place(stage, Vector2(575, 186), 136)
	Input.action_press(&"move_right")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 60), "Walking right leaves the red step")
	await _frames(2)
	player.input_component.queue_jump()
	var reached_roof := false
	for tick: int in range(120):
		await physics_frame
		if not player.jump_component.is_airborne:
			reached_roof = is_equal_approx(player.jump_component.ground_elevation, 208)
			break
	_release()
	_check(reached_roof, "A late K at the red step's edge still lands on the olive roof (floor %s)" % player.jump_component.ground_elevation)
	# How far up Billy can walk follows the floor: the lower yard stops at the
	# warehouse wall, but its side alley runs much further back.
	await _place(stage, Vector2(900, 260), 0)
	Input.action_press(&"move_up")
	await _frames(60)
	_release()
	_check(player.position.y >= 215.5 and not player.jump_component.is_airborne, "Lower yard stops at the warehouse wall (at %s)" % player.position)
	await _place(stage, Vector2(1007, 260), 0)
	Input.action_press(&"move_up")
	await _frames(120)
	_release()
	_check(player.position.y <= 140.0 and not player.jump_component.is_airborne, "The side alley lets Billy walk further up (at %s)" % player.position)
	_check(falls.is_empty() and player.health_component.current_health == 100, "Intended opening paths do not trigger pit damage")
	# Keep a genuinely missed jump: the dark opening between supports remains
	# empty, even after accepting partial foot contact at platform edges.
	await _place(stage, Vector2(336, 160), 48)
	player.position = Vector2(384, 192)
	player.terrain_motor.after_move()
	_check(player.jump_component.is_airborne, "Actual gap still requires a jump; collision fix does not add an invisible bridge")
	await AudioSettle.free_level(self, stage)
	_release()
	if failures.is_empty():
		print("INDUSTRIAL_OPENING_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("INDUSTRIAL_OPENING_SMOKE_TEST_FAIL: " + message)
		quit(1)
