extends SceneTree

const LAB := preload("res://levels/platform_test/platform_test.tscn")
var failures: Array[String] = []
var lab: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for tick: int in range(count):
		await physics_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _place(point: Vector2, height: float) -> void:
	lab.reset_player(0)
	lab.player.position = point
	lab.player.jump_component.ground_elevation = height
	lab.player.jump_component.land_immediately()
	lab.player.terrain_motor.after_move()
	await _frames(2)


func _move(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _run() -> void:
	lab = LAB.instantiate()
	lab.spawn_enemies = false
	root.add_child(lab)
	await _frames(3)
	for tier: int in range(3):
		var left := 110.0 + tier * 100
		var height := tier * 32.0
		await _place(Vector2(left - 25, 235), height)
		await _move(&"move_right", 20)
		_check(lab.player.position.x < left and lab.player.jump_component.ground_elevation == height, "Tier %d face blocks walking" % (tier + 1))
		lab.player.input_component.queue_jump()
		await _move(&"move_right", 32)
		await _frames(40)
		_check(lab.player.jump_component.ground_elevation == height + 32, "Jump lands on tier %d" % (tier + 1))
		# Front edges remain open; rear boundaries block walking and jumping.
		for direction: StringName in [&"move_down"]:
			await _place(Vector2(left + 30, 235 if direction == &"move_down" else 175), height + 32)
			Input.action_press(direction)
			for tick: int in range(60):
				await _frames(1)
				if lab.player.jump_component.is_airborne:
					break
			Input.action_release(direction)
			_check(lab.player.jump_component.is_airborne, "Tier %d edge starts a fall (%s)" % [tier + 1, direction])
			await _frames(80)
			_check(lab.player.jump_component.ground_elevation == 0 and not lab.player.jump_component.is_airborne, "Tier %d edge lands on ground (%s)" % [tier + 1, direction])
		await _place(Vector2(left + 30, 175), height + 32)
		await _move(&"move_up", 60)
		_check(lab.player.position.y >= 167.9 and not lab.player.jump_component.is_airborne, "Rear boundary stops walking on tier %d" % (tier + 1))
		lab.player.input_component.queue_jump()
		await _move(&"move_up", 80)
		_check(lab.player.position.y >= 167.9 and lab.player.jump_component.ground_elevation == height + 32, "Rear boundary stops jumps on tier %d" % (tier + 1))
		# Each amber block stops Billy, then permits jumping onto its top.
		await _place(Vector2(150 + tier * 100 - 38, 201), height + 32)
		await _move(&"move_right", 20)
		var stopped: float = lab.player.position.x
		await _move(&"move_right", 10)
		_check(absf(lab.player.position.x - stopped) < 0.1, "Tier %d block stops walking" % (tier + 1))
		lab.player.input_component.queue_jump()
		await _move(&"move_right", 20)
		await _frames(60)
		_check(lab.player.jump_component.ground_elevation == height + 52, "Tier %d block top catches jump" % (tier + 1))
	await _place(Vector2(65, 175), 0)
	await _move(&"move_up", 60)
	_check(lab.player.position.y >= 167.9, "Ground rear boundary stops Billy")
	# Right side of the highest tier drops all the way to ground.
	await _place(Vector2(510, 235), 96)
	await _move(&"move_right", 20)
	_check(lab.player.jump_component.is_airborne, "Outer side starts a fall")
	await _frames(80)
	_check(lab.player.jump_component.ground_elevation == 0, "Outer side lands on ground")
	_check(lab.player.health_component.current_health == 100, "Safe ground falls preserve health")
	await preload("res://tools/lib/audio_settle.gd").free_level(self, lab)
	if failures.is_empty():
		print("PLATFORM_LAB_SMOKE_TEST_PASS")
		quit()
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
