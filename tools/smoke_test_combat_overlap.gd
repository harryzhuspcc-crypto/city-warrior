extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await physics_frame
	player.set_physics_process(false)

	var target := Node2D.new()
	target.global_position = player.global_position
	var health := HealthComponent.new()
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	collision.position = Vector2(20.0, -28.0)
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.add_child(collision)
	hurtbox.health_component = health
	target.add_child(health)
	target.add_child(hurtbox)
	var stats := FighterStats.new()
	health.configure(stats)
	root.add_child(target)
	await physics_frame

	var landed_hits: Array[int] = [0]
	player.combat_component.hit_landed.connect(
		func(_target: HurtboxComponent, _attack: AttackData, _knockback: Vector2) -> void:
			landed_hits[0] += 1
	)
	if not player.combat_component.try_start_attack():
		_fail("Physical-overlap punch did not start")
		return

	for _frame: int in range(
		player.combat_component.attack_data.startup_frames
		+ player.combat_component.attack_data.active_frames
	):
		player.combat_component.physics_tick()
		await physics_frame

	if health.current_health != stats.max_health - player.combat_component.attack_data.damage:
		_fail("Physics-backed Area2D overlap did not apply exactly one punch")
		return
	if landed_hits[0] != 1:
		_fail("Physics-backed overlap emitted %d hits instead of one" % landed_hits[0])
		return

	player.combat_component.cancel_attack()
	await process_frame
	if not player.combat_component.try_start_attack(player.kick_attack_data):
		_fail("Physical-overlap kick did not start")
		return
	for _frame: int in range(
		player.kick_attack_data.startup_frames + player.kick_attack_data.active_frames
	):
		player.combat_component.physics_tick()
		await physics_frame
	var expected_health := (
		stats.max_health
		- player.combat_component.attack_data.damage
		- player.kick_attack_data.damage
	)
	if health.current_health != expected_health:
		_fail("Physics-backed Area2D kick did not apply exactly one kick")
		return
	if landed_hits[0] != 2:
		_fail("Punch plus kick emitted %d hits instead of two" % landed_hits[0])
		return

	player.combat_component.cancel_attack()
	target.queue_free()
	await physics_frame

	var victim := PLAYER_SCENE.instantiate() as Player
	root.add_child(victim)
	victim.global_position = player.global_position + Vector2(20.0, 0.0)
	victim.set_physics_process(false)
	victim.get_node("Hurtbox").collision_layer = 8
	victim.get_node("Hurtbox").collision_mask = 0
	victim.combat_component.hitbox.collision_mask = 0
	victim.health_component.take_damage(victim.health_component.current_health - 1)
	victim.combat_component.try_start_attack()
	for _frame: int in range(victim.combat_component.attack_data.startup_frames):
		victim.combat_component.physics_tick()
	if not victim.combat_component.is_hitbox_active:
		_fail("Lethal-overlap victim was not attacking during the regression setup")
		return
	await physics_frame

	if not player.combat_component.try_start_attack():
		_fail("Lethal-overlap punch did not start")
		return
	for _frame: int in range(player.combat_component.attack_data.startup_frames + 1):
		player.combat_component.physics_tick()
		await physics_frame
	await process_frame

	if not victim.health_component.is_dead():
		_fail("Lethal physics overlap did not kill its victim")
		return
	if victim.combat_component.is_attacking or victim.combat_component.is_hitbox_active:
		_fail("Death did not cancel the victim's active attack logically")
		return
	if victim.combat_component.hitbox.monitoring or not victim.combat_component.hitbox_shape.disabled:
		_fail("Deferred death cancellation did not disable the physical hitbox")
		return

	print("COMBAT_OVERLAP_SMOKE_TEST_PASS")
	quit()


func _fail(message: String) -> void:
	push_error("COMBAT_OVERLAP_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
