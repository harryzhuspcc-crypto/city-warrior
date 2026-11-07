extends "res://tools/smoke_test_industrial_terrain.gd"
## Exercise real direction events, including the double-tap attack recognizer.

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	var stage := await _new_stage()
	for direction: Key in [KEY_D, KEY_RIGHT]:
		for delay: int in [-2, 0, 2]:
			await _place(stage, Vector2(465, 140), 104)
			for height: int in [152, 192]:
				# Adjust position, release, then press direction + jump.
				_key(direction, true)
				await _frames(2)
				_key(direction, false)
				await _frames(2)
				_key(KEY_K if delay < 0 else direction, true)
				await _frames(absi(delay))
				_key(direction if delay < 0 else KEY_K, true)
				var jumped := await _until(func() -> bool: return stage.player.jump_component.is_airborne, 12)
				_check(jumped, "Direction %s / delay %s: K starts jump to %s" % [direction, delay, height])
				_key(KEY_K, false)
				await _until(func() -> bool: return not stage.player.jump_component.is_airborne, 100)
				_key(direction, false)
				_check(stage.player.jump_component.ground_elevation == height, "Direction %s / delay %s: expected %s, got %s" % [direction, delay, height, stage.player.jump_component.ground_elevation])
				await _frames(20)
	await AudioSettle.free_level(self, stage)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("INDUSTRIAL_KEYBOARD_JUMP_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
