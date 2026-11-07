extends "res://tools/smoke_test_industrial_terrain.gd"
## Rear wall regression. Exposed front/side drops are tested in industrial_blocks.

func _run() -> void:
	var stage := await _new_stage()
	var player := stage.player
	player.set_collision_mask_value(8, false)
	for x: float in [704, 760, 816]:
		for jumping: bool in [false, true]:
			await _place(stage, Vector2(x, 160), 192)
			if jumping:
				player.input_component.queue_jump()
			Input.action_press(&"move_up")
			await _frames(80)
			_release()
			_check(player.position.y >= 143.9, "Factory rear boundary stops walking/jumping")
			_check(not player.jump_component.is_airborne and player.jump_component.ground_elevation == 192, "Rear wall retains the roof floor")
	_check(player.health_component.current_health == 100, "Rear boundary does not cause pit damage")
	await AudioSettle.free_level(self, stage)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("INDUSTRIAL_NO_FALLS_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
