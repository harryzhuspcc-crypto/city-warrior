extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var lab := preload("res://levels/platform_test/platform_test.tscn").instantiate()
	var failures: Array[String] = []
	# These must exist before _ready: the editor needs an authored scene.
	for path: String in ["Scenery/Level1/Top", "Scenery/Level2/Top", "Scenery/Level3/Top", "Actors/Player", "Actors/SparringEnemy3"]:
		if not lab.has_node(path):
			failures.append("Missing editor-visible node: " + path)
	root.add_child(lab)
	if lab.enemies.size() != 4:
		failures.append("Expected four sparring enemies")
	for tier: int in range(lab.enemies.size()):
		var enemy: EnemyFighter = lab.enemies[tier]
		if enemy.target != lab.player or enemy.terrain_motor == null:
			failures.append("Enemy lacks player target or terrain motor")
		if not is_equal_approx(enemy.combat_elevation(), tier * 32.0):
			failures.append("Enemy spawned on wrong tier")
	# World boundary stays solid for every elevation, including during jumps.
	await physics_frame
	for enemy: EnemyFighter in lab.enemies:
		var probe := enemy.global_transform
		probe.origin.y = 175
		lab.terrain.sync_platform_collisions(enemy, 160.0, 0.0, false)
		if not enemy.test_move(probe, Vector2(0, -30)):
			failures.append("Upper boundary failed to block an airborne enemy")
	# Verify actual AI movement before isolating gravity from pursuit.
	var ground_enemy: EnemyFighter = lab.enemies[0]
	var start := ground_enemy.position
	for tick: int in range(60):
		await physics_frame
	if ground_enemy.position.distance_to(start) < 1:
		failures.append("Ground enemy never pursued Billy")
	for enemy: EnemyFighter in lab.enemies:
		enemy.acquire_player_target = false
		enemy.set_target(null)
		enemy.position.y = 285
		enemy.terrain_motor.after_move()
	for tick: int in range(90):
		await physics_frame
	for enemy: EnemyFighter in lab.enemies:
		if not is_zero_approx(enemy.combat_elevation()) or enemy.terrain_motor.is_falling():
			failures.append("Enemy failed to land on ground beyond platform boundary")
	await preload("res://tools/lib/audio_settle.gd").free_level(self, lab)
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("PLATFORM_LAB_ENEMIES_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
