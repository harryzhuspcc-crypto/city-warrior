extends SceneTree

const PROTOTYPE_ALLEY_SCENE: PackedScene = preload(
	"res://levels/prototype_alley/prototype_alley.tscn"
)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var alley := PROTOTYPE_ALLEY_SCENE.instantiate()
	root.add_child(alley)
	await physics_frame

	var error := _test_level_contract(alley)
	if not error.is_empty():
		_fail(error)
		return

	var player := alley.get_node("Actors/Player") as Player
	player.set_physics_process(false)

	error = _test_jump(player)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_combat(player)
	if not error.is_empty():
		_fail(error)
		return

	error = _test_attack_buffer()
	if not error.is_empty():
		_fail(error)
		return
	await process_frame

	error = _test_buffered_player_attacks(player)
	if not error.is_empty():
		_fail(error)
		return

	print("STEPS_4_5_SMOKE_TEST_PASS")
	quit()


func _test_level_contract(alley: Node) -> String:
	var actors := alley.get_node_or_null("Actors") as Node2D
	if actors == null or not actors.y_sort_enabled:
		return "Prototype alley requires a Y-sorted Actors container"
	if actors.get_node_or_null("Player") == null:
		return "Player must be a direct child of the Y-sorted Actors container"

	var world_geometry := alley.get_node_or_null("WorldGeometry")
	if world_geometry == null or world_geometry.get_child_count() != 4:
		return "Prototype alley requires four world boundaries"
	for boundary: Node in world_geometry.get_children():
		if not boundary is StaticBody2D:
			return "Every world boundary must be a StaticBody2D"
		var body := boundary as StaticBody2D
		if body.collision_layer != 1:
			return "World boundaries must occupy collision layer 1"
		var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape == null or shape.shape == null or shape.scale != Vector2.ONE:
			return "Every boundary requires an unscaled collision shape"
	return ""


func _test_jump(player: Player) -> String:
	var jump := player.jump_component
	var body_start := player.global_position
	var visual_start := player.visuals.position
	var landed_count: Array[int] = [0]
	jump.landed.connect(func() -> void: landed_count[0] += 1)

	if not jump.try_jump():
		return "Grounded jump request was rejected"
	if jump.try_jump():
		return "Airborne jump request incorrectly reset the jump"

	jump.physics_tick(1.0 / 60.0)
	if jump.jump_height <= 0.0 or player.visuals.position.y >= visual_start.y:
		return "Jump did not lift Visuals above the ground plane"
	if player.global_position != body_start:
		return "Jump changed the CharacterBody2D ground position"

	var safety_ticks: int = 0
	while jump.is_airborne and safety_ticks < 300:
		jump.physics_tick(1.0 / 60.0)
		safety_ticks += 1
	if jump.is_airborne or jump.jump_height != 0.0 or jump.jump_velocity != 0.0:
		return "Jump did not clamp cleanly to the ground"
	if player.visuals.position != visual_start:
		return "Visuals did not return exactly to their grounded position"
	if landed_count[0] != 1:
		return "Jump must emit landed exactly once"
	return ""


func _test_combat(player: Player) -> String:
	var combat := player.combat_component
	var attack := combat.attack_data
	if attack == null:
		return "CombatComponent has no AttackData"
	if (
		attack.startup_frames != 5
		or attack.active_frames != 3
		or attack.recovery_frames != 10
		or attack.total_frames() != 18
	):
		return "Punch timing must be exactly 5 startup, 3 active, 10 recovery"

	if not combat.try_start_attack():
		return "CombatComponent rejected an idle attack"
	for elapsed_frame: int in range(attack.total_frames() + 1):
		if elapsed_frame < attack.startup_frames:
			if combat.current_phase != CombatComponent.STARTUP or combat.is_hitbox_active:
				return "Startup phase or hitbox timing is incorrect at frame %d" % elapsed_frame
		elif elapsed_frame < attack.startup_frames + attack.active_frames:
			if combat.current_phase != CombatComponent.ACTIVE or not combat.is_hitbox_active:
				return "Active phase or hitbox timing is incorrect at frame %d" % elapsed_frame
		elif elapsed_frame < attack.total_frames():
			if combat.current_phase != CombatComponent.RECOVERY or combat.is_hitbox_active:
				return "Recovery phase or hitbox timing is incorrect at frame %d" % elapsed_frame
		elif combat.is_attacking or combat.current_phase != CombatComponent.INACTIVE:
			return "Attack did not finish exactly at frame 18"

		if elapsed_frame < attack.total_frames():
			combat.physics_tick()

	combat.set_facing(-1.0)
	if not combat.try_start_attack():
		return "Second attack did not start"
	for _frame: int in range(attack.startup_frames):
		combat.physics_tick()
	if combat.attack_facing != -1.0 or combat.hitbox_shape.position.x >= 0.0:
		return "Left-facing attack did not mirror its hitbox offset"

	var target := Node2D.new()
	var target_health := HealthComponent.new()
	var target_hurtbox := HurtboxComponent.new()
	var target_stats := FighterStats.new()
	target.add_child(target_health)
	target.add_child(target_hurtbox)
	target_hurtbox.health_component = target_health
	target_health.configure(target_stats)
	root.add_child(target)

	if not combat.resolve_hurtbox(target_hurtbox):
		return "Active hitbox did not resolve a valid hurtbox"
	if combat.resolve_hurtbox(target_hurtbox):
		return "One attack damaged the same target more than once"
	if target_health.current_health != target_stats.max_health - attack.damage:
		return "Resolved punch applied the wrong damage"

	combat.set_facing(1.0)
	if combat.attack_facing != -1.0 or combat.hitbox_shape.position.x >= 0.0:
		return "Facing changed during an active punch instead of remaining latched"
	combat.cancel_attack()
	await process_frame
	if combat.is_hitbox_active or not combat.hitbox_shape.disabled:
		return "Cancelling an attack did not disable the hitbox"

	if not combat.try_start_attack():
		return "Attack did not restart after cancellation"
	for _frame: int in range(attack.startup_frames):
		combat.physics_tick()
	if not combat.resolve_hurtbox(target_hurtbox):
		return "A new attack did not clear already-hit targets"
	if target_health.current_health != target_stats.max_health - attack.damage * 2:
		return "Second attack did not apply exactly one additional hit"
	combat.cancel_attack()
	await process_frame
	target.queue_free()
	return ""


func _test_attack_buffer() -> String:
	var input := PlayerInputComponent.new()
	input.queue_attack()
	for _frame: int in range(input.attack_buffer_frames - 1):
		input.end_physics_tick()
	if input.attack_buffer_frames_remaining != 1 or not input.consume_attack():
		return "Attack buffer was not valid on its final frame"

	input.queue_attack()
	for _frame: int in range(input.attack_buffer_frames):
		input.end_physics_tick()
	if input.attack_buffer_frames_remaining != 0 or input.consume_attack():
		return "Expired attack buffer remained consumable"

	input.queue_kick()
	for _frame: int in range(input.attack_buffer_frames - 1):
		input.end_physics_tick()
	if input.kick_buffer_frames_remaining != 1 or not input.consume_kick():
		return "Kick buffer was not valid on its final frame"
	input.queue_kick()
	for _frame: int in range(input.attack_buffer_frames):
		input.end_physics_tick()
	if input.kick_buffer_frames_remaining != 0 or input.consume_kick():
		return "Expired kick buffer remained consumable"

	input.queue_attack()
	input.queue_kick()
	if input.consume_attack() or not input.consume_kick():
		return "Latest kick input did not replace the older punch buffer"
	input.queue_kick()
	input.queue_attack()
	if input.consume_kick() or not input.consume_attack():
		return "Latest punch input did not replace the older kick buffer"

	var kick_event := InputEventAction.new()
	kick_event.action = &"kick"
	kick_event.pressed = true
	var punch_event := InputEventAction.new()
	punch_event.action = &"attack"
	punch_event.pressed = true
	input._unhandled_input(kick_event)
	input._unhandled_input(punch_event)
	Input.action_press(&"kick")
	Input.action_press(&"attack")
	input.physics_tick()
	Input.action_release(&"kick")
	Input.action_release(&"attack")
	if input.consume_kick() or not input.consume_attack():
		return "Physics polling overwrote the latest real attack-event order"
	input.end_physics_tick()
	input.free()
	return ""


func _test_buffered_player_attacks(player: Player) -> String:
	var combat := player.combat_component
	var input := player.input_component
	input.clear_buffered_actions()
	combat.cancel_attack()

	if not combat.try_start_attack():
		return "Could not start attack for early-buffer integration test"
	input.queue_attack()
	for _frame: int in range(combat.attack_data.total_frames()):
		player._physics_process(1.0 / 60.0)
	if combat.is_attacking:
		return "Attack buffered during startup did not expire before recovery ended"

	if not combat.try_start_attack():
		return "Could not start attack for late-buffer integration test"
	while combat.attack_frame < combat.attack_data.total_frames() - 2:
		player._physics_process(1.0 / 60.0)
	input.queue_attack()
	player._physics_process(1.0 / 60.0)
	player._physics_process(1.0 / 60.0)
	if not combat.is_attacking or combat.attack_frame != 0:
		return "Late-recovery buffered punch did not chain on the first eligible tick"

	combat.cancel_attack()
	input.clear_buffered_actions()
	if not combat.try_start_attack():
		return "Could not start punch for buffered-kick integration test"
	while combat.attack_frame < combat.attack_data.total_frames() - 2:
		player._physics_process(1.0 / 60.0)
	input.queue_kick()
	player._physics_process(1.0 / 60.0)
	player._physics_process(1.0 / 60.0)
	if not combat.is_attacking or combat.current_attack_data != player.kick_attack_data:
		return "Late-recovery buffered kick did not chain from punch"
	if combat.attack_frame != 0:
		return "Buffered kick did not begin at frame zero"

	combat.cancel_attack()
	input.clear_buffered_actions()
	return ""


func _fail(message: String) -> void:
	push_error("STEPS_4_5_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
