extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	for scene_path: String in ["res://features/actors/enemies/williams/williams.tscn", "res://features/actors/enemies/linda/linda.tscn"]:
		var lab := preload("res://levels/platform_test/platform_test.tscn").instantiate()
		lab.spawn_enemies = false
		root.add_child(lab)
		lab.reset_player(3)
		lab.player.set_physics_process(false)
		lab.player.hurtbox.is_invulnerable = true
		var enemy := (load(scene_path) as PackedScene).instantiate() as EnemyFighter
		enemy.position = Vector2(65, 235)
		enemy.can_follow_platforms = true
		lab.get_node("Actors").add_child(enemy)
		lab.terrain.attach_actor(enemy)
		enemy.set_target(lab.player)
		var saw_air := false
		var reached := false
		for tick: int in range(2400):
			await physics_frame
			saw_air = saw_air or enemy.terrain_motor.is_falling()
			if not enemy.terrain_motor.is_falling() and is_equal_approx(enemy.combat_elevation(), 96) and enemy.position.distance_to(lab.player.position) < 40:
				reached = true
				break
		if not saw_air or not reached:
			failures.append("%s failed ascent: position %s height %s" % [scene_path, enemy.position, enemy.combat_elevation()])
		# Starting beside the tall outer wall requires routing via lower steps.
		lab.reset_player(0)
		lab.player.position = Vector2(550, 235)
		for tick: int in range(2400):
			await physics_frame
			if not enemy.terrain_motor.is_falling() and is_zero_approx(enemy.combat_elevation()) and enemy.position.distance_to(lab.player.position) < 40:
				break
		lab.reset_player(3)
		for tick: int in range(3600):
			await physics_frame
			if not enemy.terrain_motor.is_falling() and is_equal_approx(enemy.combat_elevation(), 96) and enemy.position.distance_to(lab.player.position) < 40:
				break
		if not is_equal_approx(enemy.combat_elevation(), 96) or enemy.position.distance_to(lab.player.position) >= 40:
			failures.append("Enemy failed to route around the tall outer wall: %s height %s" % [enemy.position, enemy.combat_elevation()])
		lab.reset_player(0)
		for tick: int in range(2400):
			await physics_frame
			if not enemy.terrain_motor.is_falling() and is_zero_approx(enemy.combat_elevation()) and enemy.position.distance_to(lab.player.position) < 40:
				break
		if not is_zero_approx(enemy.combat_elevation()) or enemy.position.distance_to(lab.player.position) >= 40:
			failures.append("Enemy failed to follow back to ground")
		var attacks: Array[int] = []
		enemy.combat_component.attack_started.connect(func() -> void: attacks.append(1))
		for tick: int in range(120):
			await physics_frame
		if attacks.is_empty():
			failures.append("Enemy failed to resume combat after pursuit")
		await preload("res://tools/lib/audio_settle.gd").free_level(self, lab)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("ENEMY_PLATFORM_PURSUIT_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
