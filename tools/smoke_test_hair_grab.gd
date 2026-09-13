extends SceneTree

const PLAYER := preload("res://features/actors/player/player.tscn")
const ENEMY := preload("res://features/actors/enemies/williams/williams.tscn")
var failures: Array[String] = []
var player: Player
var enemy: Williams


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _spawn(direction: float = 1.0) -> void:
	player = PLAYER.instantiate() as Player
	enemy = ENEMY.instantiate() as Williams
	player.position = Vector2(200, 150)
	enemy.position = player.position + Vector2(35 * direction, 0)
	enemy.acquire_player_target = false
	root.add_child(player)
	root.add_child(enemy)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	await physics_frame


func _cleanup() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await physics_frame
	await physics_frame


func _hit() -> void:
	_check(enemy.hurtbox.receive_attack(player.combat_component.attack_data, Vector2.ZERO, player), "Setup hit must land")


func _tick(count: int = 1) -> void:
	for index: int in range(count):
		if is_instance_valid(player):
			player._physics_process(1.0 / 60.0)
		if is_instance_valid(enemy):
			enemy._physics_process(1.0 / 60.0)
		await physics_frame


func _grab(direction: float = 1.0, settle_frames: int = 8) -> bool:
	_hit()
	_hit()
	Input.action_press(&"move_right" if direction > 0 else &"move_left")
	for index: int in range(25):
		await _tick()
		if player.hair_grab_component.is_active():
			break
	Input.action_release(&"move_right" if direction > 0 else &"move_left")
	var grabbed := player.hair_grab_component.is_active()
	_check(grabbed, "Walking into status2 body contact must grab in either facing")
	await _tick(settle_frames)
	return grabbed


func _run() -> void:
	await _spawn()
	var reaction := enemy.hit_reaction_component
	var enemy_sounds: Array[Node] = []
	enemy.audio_component.playback_requested.connect(func(sound: Node) -> void: enemy_sounds.append(sound))
	_hit()
	_check(reaction.current_reaction == HitReactionComponent.STATUS1, "First hit is status1")
	_check(enemy.visuals.animated_sprite.animation == &"status1", "Status1 reference animation is immediate")
	for index: int in range(enemy.fighter_stats.status1_frames - 1):
		reaction.physics_tick()
	_check(reaction.current_reaction == HitReactionComponent.STATUS1, "Status1 lasts through last active frame")
	reaction.physics_tick()
	_check(not reaction.is_incapacitated() and reaction.consecutive_hits == 0, "Recovery immediately clears stage")
	_hit()
	_check(reaction.current_reaction == HitReactionComponent.STATUS1, "A hit after recovery restarts status1")
	_hit()
	_check(reaction.current_reaction == HitReactionComponent.STATUS2, "Second hit DURING status1 is status2")
	_check(enemy.visuals.animated_sprite.animation == &"status2", "Status2 stomach reference shown")
	for index: int in range(enemy.fighter_stats.status2_frames):
		reaction.physics_tick()
	_check(not enemy.can_be_hair_grabbed(), "Recovered status2 is not grabbable")
	_hit()
	_check(reaction.current_reaction == HitReactionComponent.STATUS1, "Expired status2 also resets stage")
	# Restore HP without altering the active stage, then third hit knocks down.
	enemy.health_component.restore_full_health()
	_hit()
	_hit()
	_check(reaction.current_reaction == HitReactionComponent.KNOCKDOWN, "Third hit during status2 knocks down")
	_check(enemy.hurtbox.is_invulnerable and not enemy.can_be_hair_grabbed(), "Downed enemy cannot be hit/grabbed")
	_check(enemy_sounds.is_empty(), "Nonlethal staged fall must not request fall/death SFX")
	for index: int in range(enemy.fighter_stats.knockdown_frames):
		reaction.physics_tick()
	_check(not enemy.hurtbox.is_invulnerable and reaction.consecutive_hits == 0, "Knockdown recovery restores vulnerability and stage")
	await _cleanup()

	# Resource contracts: stable 80px canvases, distinct non-looping reference clips.
	await _spawn()
	for contract: Array in [[player.visuals.animated_sprite, &"hair_grab", 4], [player.visuals.animated_sprite, &"knee", 2], [player.visuals.animated_sprite, &"hair_throw", 4], [enemy.visuals.animated_sprite, &"status1", 2], [enemy.visuals.animated_sprite, &"status2", 1], [enemy.visuals.animated_sprite, &"grabbed", 3], [enemy.visuals.animated_sprite, &"thrown", 6]]:
		var frames: SpriteFrames = contract[0].sprite_frames
		_check(frames.get_frame_count(contract[1]) == contract[2], "Reference pose count: %s" % contract[1])
		_check(not frames.get_animation_loop(contract[1]), "Paired/reaction poses must not autoplay-loop")
		for index: int in range(contract[2]):
			_check(frames.get_frame_texture(contract[1], index).get_size() == Vector2(80, 80), "Stable 80x80 pose canvas")
	_hit()
	_check(not enemy.can_be_hair_grabbed(), "Status1 cannot be grabbed")
	_check(not player.hair_grab_component.try_contact(Vector2.ZERO), "Stationary overlap is not a walking grab")
	player.jump_component.try_jump()
	_hit()
	_check(not player.can_hair_grab(), "Airborne Billy cannot grab")
	player.jump_component.land_immediately()
	player.combat_component.try_start_attack()
	_check(not player.can_hair_grab(), "Attacking Billy cannot grab")
	player.combat_component.cancel_attack()
	await _cleanup()

	# A fresh command immediately after contact cannot expire in the entry
	# pose; exercise the input event path, not only the queue helper.
	await _spawn()
	if await _grab(1.0, 0):
		var event := InputEventAction.new()
		event.action = &"kick"
		event.pressed = true
		player.input_component._unhandled_input(event)
		await _tick()
		_check(player.hair_grab_component.phase == HairGrabComponent.KNEE, "Fresh kick interrupts grab entry immediately")
	await _cleanup()

	for direction: float in [1.0, -1.0]:
		await _spawn(direction)
		if not await _grab(direction):
			await _cleanup()
			continue
		var grab := player.hair_grab_component
		_check(enemy.grab_owner == grab and enemy.state_machine.current_state == EnemyStateMachine.GRABBED, "Exclusive pair claimed")
		_check(player.state_machine.current_state == PlayerStateMachine.GRAB, "Billy presents grab state")
		_check(not enemy.can_be_hair_grabbed(), "A second grabber cannot claim a held enemy")
		_check(player.visuals.animated_sprite.flip_h == (direction < 0), "Billy grab facing latched")
		_check(enemy.visuals.animated_sprite.flip_h == (direction > 0), "Victim faces Billy")
		var start := player.position
		Input.action_press(&"move_left" if direction > 0 else &"move_right")
		await _tick(3)
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		_check(player.position.is_equal_approx(start) and grab.facing == direction, "Hold locks movement and facing")
		var health := enemy.health_component.current_health
		var knee_sounds: Array[Node] = []
		player.audio_component.playback_requested.connect(func(sound: Node) -> void: knee_sounds.append(sound))
		for knee_index: int in range(2):
			player.input_component.queue_kick()
			await _tick(20)
			_check(grab.phase == HairGrabComponent.HOLD, "Knee returns to hold")
			_check(enemy.health_component.current_health == health - (knee_index + 1) * grab.knee_attack.damage, "Each knee damages once, without third-hit knockdown")
		_check(knee_sounds.size() == 2, "Each knee requests one impact sound")
		# Give the nonlethal throw room to demonstrate its entire trajectory.
		enemy.health_component.restore_full_health()
		var initial_x := enemy.position.x
		if direction > 0:
			player.input_component.queue_attack()
		else:
			player.input_component.queue_jump()
		await _tick(20)
		_check(grab.phase == HairGrabComponent.THROW and not player.jump_component.is_airborne, "Punch OR jump starts throw, never normal attack/jump (phase=%s frame=%d reaction=%s health=%d)" % [grab.phase, grab.frame, enemy.hit_reaction_component.current_reaction, enemy.health_component.current_health])
		_check(enemy.visuals.position.y < -40.0, "Throw displays airborne victim arc")
		await _tick(20)
		_check(not grab.is_active() and enemy.grab_owner == null, "Throw completion releases both actors")
		_check((enemy.position.x - initial_x) * direction < -90, "Throw travels behind original Billy facing")
		_check(enemy.hit_reaction_component.is_knocked_down(), "Throw lands in recoverable knockdown")
		_check(enemy.visuals.animated_sprite.flip_h == (direction > 0), "Landing preserves the victim's paired facing")
		_check(enemy.visuals.position == Vector2(0, -40), "Throw restores visual baseline")
		_check(enemy.health_component.current_health == enemy.fighter_stats.max_health - grab.throw_attack.damage, "Throw damage delivered once")
		_check(player.get_collision_exceptions().is_empty() and enemy.get_collision_exceptions().is_empty(), "Throw removes pair collision exceptions")
		await _tick(60)
		_check(not enemy.hit_reaction_component.is_incapacitated(), "Thrown enemy gets up")
		await _cleanup()

	# Contextual input priority: jump-containing chords must never escape into
	# their ordinary elbow/back-kick actions during the grab.
	await _spawn()
	var inputs := player.input_component
	for chord: String in ["punch_jump", "jump_punch", "kick_jump", "jump_kick"]:
		inputs.clear_buffered_actions()
		match chord:
			"punch_jump":
				inputs.queue_attack()
				inputs.queue_jump()
			"jump_punch":
				inputs.queue_jump()
				inputs.queue_attack()
			"kick_jump":
				inputs.queue_kick()
				inputs.queue_jump()
			"jump_kick":
				inputs.queue_jump()
				inputs.queue_kick()
		_check(inputs.consume_grab_action() == &"throw", "Jump chord maps to throw: " + chord)
		_check(not inputs.consume_elbow_chord() and not inputs.consume_back_kick_chord(), "Grab consumes ordinary chord buffers")
	await _cleanup()

	# Contact against an enemy backed by a wall still pairs: Billy yields the
	# extra hand/head spacing instead of moving the captive through the wall.
	await _spawn()
	var back_wall := StaticBody2D.new()
	back_wall.position = enemy.position + Vector2(12, 0)
	var back_shape := CollisionShape2D.new()
	var back_rectangle := RectangleShape2D.new()
	back_rectangle.size = Vector2(4, 120)
	back_shape.shape = back_rectangle
	back_wall.add_child(back_shape)
	root.add_child(back_wall)
	await physics_frame
	if await _grab():
		_check(absf(enemy.position.x - player.position.x - 30.0) < 0.2, "Wall-backed acquisition preserves paired spacing (gap %.3f)" % (enemy.position.x - player.position.x))
		_check(enemy.position.x < back_wall.position.x, "Acquisition never moves Williams through a wall")
	back_wall.queue_free()
	await _cleanup()

	# A solid wall behind Billy clips throw distance, never the wall collider.
	await _spawn()
	if await _grab():
		var wall := StaticBody2D.new()
		wall.position = Vector2(150, 150)
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(8, 120)
		shape.shape = rectangle
		wall.add_child(shape)
		root.add_child(wall)
		await physics_frame
		player.input_component.queue_jump()
		await _tick(40)
		_check(enemy.position.x >= 161.0, "Backward throw respects world walls")
		_check(not player.hair_grab_component.is_active(), "Wall-clipped throw still releases")
		wall.queue_free()
	await _cleanup()

	# No lane snapping from an unrelated depth, and no acquisition from
	# stationary status2 proximity or movement away from the victim.
	await _spawn()
	_hit()
	_hit()
	enemy.position = player.position + Vector2(10, 20)
	await physics_frame
	_check(not player.hair_grab_component.try_contact(Vector2.RIGHT), "Cross-lane enemy is not contact")
	_check(not player.hair_grab_component.try_contact(Vector2.LEFT), "Walking away cannot grab")
	await _cleanup()

	# Every exit uses the same idempotent pair cleanup, including direct health
	# depletion and direct reactions rather than only hurtbox-driven damage.
	for exit_kind: String in ["player_hit", "enemy_hit", "player_death", "enemy_death", "player_remove", "enemy_remove", "player_free", "enemy_free", "direct_reaction", "player_attack", "enemy_attack", "throw_interrupt", "knee_death", "throw_death", "manual"]:
		await _spawn()
		if not await _grab():
			await _cleanup()
			continue
		var grab := player.hair_grab_component
		enemy.set_target(player)
		match exit_kind:
			"player_hit": player.hurtbox.receive_attack(enemy.combat_component.attack_data, Vector2.ZERO, enemy)
			"enemy_hit": enemy.hurtbox.receive_attack(player.combat_component.attack_data, Vector2.ZERO, null)
			"player_death": player.health_component.take_damage(1000)
			"enemy_death": enemy.health_component.take_damage(1000)
			"player_remove": root.remove_child(player)
			"enemy_remove": root.remove_child(enemy)
			"player_free": player.queue_free()
			"enemy_free": enemy.queue_free()
			"direct_reaction": enemy.hit_reaction_component.begin_death()
			"player_attack": player.combat_component.try_start_attack()
			"enemy_attack": enemy.combat_component.try_start_attack()
			"throw_interrupt":
				player.input_component.queue_jump()
				await _tick(20)
				player.hurtbox.receive_attack(enemy.combat_component.attack_data, Vector2.ZERO, enemy)
			"knee_death", "throw_death":
				enemy.health_component.take_damage(enemy.health_component.current_health - 1)
				if exit_kind == "knee_death":
					player.input_component.queue_kick()
				else:
					player.input_component.queue_jump()
				await _tick(10)
			"manual":
				grab.release()
				grab.release()
		await physics_frame
		await physics_frame
		if is_instance_valid(player):
			_check(not grab.is_active() and grab.victim == null, "Release Billy on %s" % exit_kind)
			_check(player.get_collision_exceptions().is_empty(), "Clear Billy collision exception on %s" % exit_kind)
		if is_instance_valid(enemy):
			if exit_kind in ["player_free", "player_remove"]:
				enemy._physics_process(1.0 / 60.0)
				_check(not enemy.ai_component.has_target(), "Released AI clears removed/freed Billy")
			_check(enemy.grab_owner == null, "Release Williams on %s" % exit_kind)
			_check(enemy.get_collision_exceptions().is_empty(), "Clear enemy collision exception on %s" % exit_kind)
			_check(enemy.visuals.position == Vector2(0, -40), "Restore victim baseline on %s" % exit_kind)
		await _cleanup()

	if failures.is_empty():
		print("HAIR_GRAB_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("HAIR_GRAB_SMOKE_TEST_FAIL: " + message)
		quit(1)
