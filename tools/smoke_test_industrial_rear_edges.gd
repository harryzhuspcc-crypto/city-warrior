extends "res://tools/smoke_test_industrial_terrain.gd"
## The small landing has an explicit rear boundary, but its front still drops.
func _run() -> void:
	var stage := await _new_stage()
	stage.player.set_collision_mask_value(8, false)
	# Reproduce the user's exact route: lower girder -> jump up -> W past
	# the LOWER gold line -> stop only at this landing's own gold line.
	await _place(stage, Vector2(480, 170), 80)
	Input.action_press(&"move_up")
	await _frames(24)
	_release()
	_check(stage.player.jump_component.ground_elevation == 80, "Raised front needs a jump")
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_up")
	_check(await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12), "Jump from girder starts")
	_check(await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100), "Jump onto landing settles")
	_release()
	_check(stage.player.jump_component.ground_elevation == 104, "Real girder jump lands on level 2")
	Input.action_press(&"move_up")
	await _frames(65)
	_release()
	_check(stage.player.position.y - 104.0 < 40.0, "Level 2 feet cross the lower girder gold line at screen-world y=40")
	_check(stage.player.position.y >= 135.9, "Selected edge keeps the whole foot on the landing")
	_check(stage.player.jump_component.ground_elevation == 104 and not stage.player.jump_component.is_airborne, "Small landing rear must not drop Billy into overlapping girder artwork")
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_up")
	await _frames(70)
	_release()
	_check(stage.player.jump_component.ground_elevation == 104, "Landing rear also holds during a jump")
	await _place(stage, Vector2(400, 148), 80)
	Input.action_press(&"move_up")
	await _frames(50)
	_release()
	_check(stage.player.position.y >= 127.9, "Girder boundary includes foot depth")
	_check(stage.player.jump_component.ground_elevation == 80, "Girder rear is a deliberate boundary")
	# Exercise both seams in both directions, including the diagonal around the tower.
	await _place(stage, Vector2(480, 140), 104)
	await _walk_to(stage, [&"move_right"], func() -> bool: return stage.player.position.x >= 508, "Landing east")
	await _walk_to(stage, [&"move_right", &"move_down"], func() -> bool: return stage.player.position.y >= 172, "Landing to Step2 diagonal")
	await _walk_to(stage, [&"move_right"], func() -> bool: return stage.player.position.x >= 584, "Step2 to Step1")
	await _walk_to(stage, [&"move_left"], func() -> bool: return stage.player.position.x <= 540, "Step1 to Step2")
	await _walk_to(stage, [&"move_left", &"move_up"], func() -> bool: return stage.player.position.y <= 140, "Step2 to landing diagonal")
	await _walk_to(stage, [&"move_left"], func() -> bool: return stage.player.position.x <= 480, "Landing west")
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	var player := stage.player
	player.set_physics_process(false)
	var mask := player.collision_mask
	player.collision_mask = 1
	var transform := player.global_transform
	transform.origin = Vector2(480, 145)
	terrain.sync_rear_wall_collisions(player, 80, false)
	_check(not player.test_move(transform, Vector2(0, -10)), "Landing wall does not block the girder floor below")
	terrain.sync_rear_wall_collisions(player, 104, false)
	_check(player.test_move(transform, Vector2(0, -10)), "Same projected edge physically blocks the landing floor")
	player.collision_mask = mask
	player.set_physics_process(true)
	await AudioSettle.free_level(self, stage)
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("INDUSTRIAL_REAR_EDGES_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)

func _walk_to(stage: PrototypeAlley, actions: Array[StringName], reached: Callable, label: String) -> void:
	for action: StringName in actions:
		Input.action_press(action)
	var stayed_supported := true
	for tick: int in range(100):
		await physics_frame
		stayed_supported = stayed_supported and not stage.player.jump_component.is_airborne and stage.player.jump_component.ground_elevation == 104.0
		if reached.call():
			break
	_release()
	_check(reached.call() and stayed_supported, label + " stays on the connected 104 floor without jumping (at %s)" % stage.player.position)
