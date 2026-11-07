extends "res://tools/smoke_test_industrial_terrain.gd"
## Blue-outline geometry: raised faces block, exposed tops drop, rear walls hold.

func _run() -> void:
	var stage := await _new_stage()
	var player := stage.player
	player.set_collision_mask_value(8, false)
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	var background := stage.get_node("PlatformBlocks/Background") as Sprite2D
	var outlines := stage.get_node("PlatformBlocks/CollisionOutlines") as Node2D
	_check(background.is_visible_in_tree() and not outlines.is_visible_in_tree(), "Gameplay begins with the fixed picture and hidden outlines")
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_B
	toggle.pressed = true
	stage._unhandled_key_input(toggle)
	_check(background.is_visible_in_tree() and outlines.is_visible_in_tree(), "B shows only the collision guide over the fixed picture")
	stage._unhandled_key_input(toggle)
	_check(terrain.floor_at(425, 130, 104) != 104, "Point left of the original landing polygon does not support Billy at height 128")
	for side: String in ["Left", "Right"]:
		for tier: int in range(3):
			var name := "%sCrateTier%d" % [side, tier + 1]
			var wall := terrain.get_node(name + "Blocker") as StaticBody2D
			var height := (240.0 if side == "Left" else 216.0) + tier * 24.0
			terrain.sync_platform_collisions(player, 192, 0, false)
			_check(not player.get_collision_exceptions().has(wall), name + " blocks the deck below")
			terrain.sync_platform_collisions(player, height, 0, false)
			_check(player.get_collision_exceptions().has(wall), name + " clears at its own top")
	# A crate is now a real top: normal jump from its front lands on it.
	await _place(stage, Vector2(850, 167), 192)
	Input.action_press(&"move_up")
	await _frames(20)
	_release()
	_check(player.jump_component.ground_elevation == 192, "Right crate face cannot be walked through")
	player.input_component.queue_jump()
	Input.action_press(&"move_up")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 12), "Jump at crate starts")
	_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 100), "Jump at crate lands")
	_release()
	_check(player.jump_component.ground_elevation == 216, "Lowest right crate is a separate landing surface (got %s at %s)" % [player.jump_component.ground_elevation, player.position])
	# Front roof drops to the actual lower yard; left roof drops to steel.
	for fixture: Vector3 in [Vector3(900, 212, 0), Vector3(620, 176, 104)]:
		await _place(stage, Vector2(fixture.x, fixture.y), 192)
		Input.action_press(&"move_down" if fixture.z == 0 else &"move_left")
		_check(await _until(func() -> bool: return player.jump_component.is_airborne, 70), "Exposed deck edge starts falling")
		_release()
		_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 120), "Deck fall settles")
		_check(player.jump_component.ground_elevation == fixture.z, "Deck fall lands on %s (got %s at %s)" % [fixture.z, player.jump_component.ground_elevation, player.position])
	await _place(stage, Vector2(760, 160), 192)
	await _hold(&"move_up", 70)
	_check(player.position.y >= 143.9 and not player.jump_component.is_airborne, "Rear factory wall blocks walking")
	player.input_component.queue_jump()
	await _hold(&"move_up", 80)
	_check(player.position.y >= 143.9 and player.jump_component.ground_elevation == 192, "Rear factory wall also blocks jumping")
	await _place(stage, Vector2(840, 148), 320)
	await _hold(&"move_up", 30)
	_check(player.jump_component.ground_elevation == 320 and not player.jump_component.is_airborne, "Awning rear stays protected")
	await _place(stage, Vector2(840, 152), 320)
	Input.action_press(&"move_down")
	_check(await _until(func() -> bool: return player.jump_component.is_airborne, 30), "Awning front drops (at %s height %s climb %s)" % [player.position, player.jump_component.ground_elevation, player.climb_component.is_elevated()])
	_release()
	_check(await _until(func() -> bool: return not player.jump_component.is_airborne, 120), "Awning fall lands")
	_check(player.jump_component.ground_elevation == 192, "Awning fall reaches deck")
	_check(player.health_component.current_health == 100, "Supported drops preserve health")
	await AudioSettle.free_level(self, stage)
	await _test_edited_outline()
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("INDUSTRIAL_BLOCKS_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)


func _test_edited_outline() -> void:
	var stage := YARD.instantiate() as PrototypeAlley
	var outline := stage.get_node("PlatformBlocks/CollisionOutlines/Surfaces/StepLanding") as Polygon2D
	var points := outline.polygon
	points[0].x -= 20
	outline.polygon = points
	root.add_child(stage)
	await _frames(2)
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	var background := stage.get_node("PlatformBlocks/Background") as Sprite2D
	_check(terrain.floor_at(425, 130, 104) == 104, "Moving a corner of the authored polygon extends runtime support")
	_check(background.position == Vector2(0, -264) and background.texture.resource_path == "res://assets/stages/industrial_yard.png", "Editing terrain leaves the fixed original sprite in place")
	await AudioSettle.free_level(self, stage)


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	_release()
