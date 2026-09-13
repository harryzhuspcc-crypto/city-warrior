extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")
const WILLIAMS_SCENE: PackedScene = preload("res://features/actors/enemies/williams/williams.tscn")
const DELTA: float = 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await physics_frame
	player.set_physics_process(false)

	var attacks: Dictionary[StringName, AttackData] = {}
	for property_name: StringName in [
		&"elbow_attack_data",
		&"head_attack_data",
		&"back_kick_attack_data",
		&"jump_kick_attack_data",
	]:
		var attack := player.get(property_name) as AttackData
		if attack == null:
			_fail("Player is missing %s" % property_name)
			return
		attacks[property_name] = attack

	var frames := player.visuals.animated_sprite.sprite_frames
	for animation_contract: Array in [
		[&"elbow", 2],
		[&"head_attack", 3],
		[&"back_kick", 5],
		[&"jump_kick", 5],
	]:
		var animation_name := animation_contract[0] as StringName
		var expected_count := animation_contract[1] as int
		if not frames.has_animation(animation_name):
			_fail("Missing special-move animation: %s" % animation_name)
			return
		if frames.get_frame_count(animation_name) != expected_count:
			_fail("%s must contain exactly %d referenced poses" % [
				animation_name,
				expected_count,
			])
			return
		for frame_index: int in range(expected_count):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			var source_frame_index := frame_index
			if animation_name == &"head_attack" and frame_index == 2:
				source_frame_index = 0
			if not texture.resource_path.ends_with("%s_%02d.png" % [
				animation_name,
				source_frame_index,
			]):
				_fail("%s pose %d has the wrong source texture" % [
					animation_name,
					frame_index,
				])
				return

	var elbow := attacks[&"elbow_attack_data"]
	var head_attack := attacks[&"head_attack_data"]
	var back_kick := attacks[&"back_kick_attack_data"]
	var jump_kick := attacks[&"jump_kick_attack_data"]
	if elbow.hit_direction_multiplier != -1 or back_kick.hit_direction_multiplier != -1:
		_fail("Elbow and back kick must direct their hitboxes behind Billy")
		return
	if not back_kick.reverse_facing_on_finish:
		_fail("Back kick must reverse Billy's facing when it finishes")
		return
	if not back_kick.starts_jump or not jump_kick.allow_air_movement:
		_fail("Aerial special-move movement flags are not configured")
		return
	if absf(back_kick.jump_height_scale - 0.25) > 0.001:
		_fail("Back kick is not configured for a quarter-height jump")
		return
	if (
		not back_kick.finishes_on_landing
		or not jump_kick.finishes_on_landing
		or back_kick.landing_hold_frame != 10
		or jump_kick.landing_hold_frame != 8
	):
		_fail("Aerial kicks are missing their landing-held extension frames")
		return
	if head_attack.movement_speed <= 0.0 or head_attack.movement_end_frame <= 0:
		_fail("Head attack requires data-driven forward travel")
		return
	if head_attack.animation_frame_starts != PackedInt32Array([0, 5, 10]):
		_fail("Head attack must play pose 1, attacking pose 2, then pose 1")
		return
	if head_attack.animation_facing_multiplier != 1:
		_fail("Head-attack source art must be authored rightward")
		return
	var schedule_error := _test_pose_schedules(player, [
		elbow,
		head_attack,
		back_kick,
		jump_kick,
	])
	if not schedule_error.is_empty():
		_fail(schedule_error)
		return

	var error := _test_input_recognition(player.input_component)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_player_specials(player, elbow, head_attack, back_kick, jump_kick)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_williams_special_falls(player, [elbow, back_kick, jump_kick])
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_rear_physical_hits(player, elbow, back_kick)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_head_final_active_hit(player, head_attack)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_jump_kick_physical_hit(player, jump_kick)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_reentrant_hit_cancellation(player)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_reentrant_attack_replacement(player, elbow, back_kick)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_no_post_landing_hit(player, jump_kick)
	if not error.is_empty():
		_fail(error)
		return

	error = await _test_back_kick_death_cancellation()
	if not error.is_empty():
		_fail(error)
		return

	print("SPECIAL_MOVES_SMOKE_TEST_PASS")
	quit()


func _test_input_recognition(input: PlayerInputComponent) -> String:
	for method_name: StringName in [
		&"consume_elbow_chord",
		&"consume_back_kick_chord",
		&"queue_direction_tap",
		&"consume_head_attack_direction",
	]:
		if not input.has_method(method_name):
			return "InputComponent is missing %s" % method_name

	input.clear_buffered_actions()
	input.queue_attack()
	input.queue_jump()
	if not input.consume_elbow_chord():
		return "J+K did not resolve as the grounded elbow chord"
	if input.consume_attack() or input.consume_jump():
		return "Elbow chord did not consume both component actions"

	input.queue_kick()
	input.queue_jump()
	if not input.consume_back_kick_chord():
		return "L+K did not resolve as the grounded back-kick chord"
	if input.consume_kick() or input.consume_jump():
		return "Back-kick chord did not consume both component actions"
	input.queue_jump()
	input.queue_attack()
	if not input.consume_elbow_chord():
		return "K then J did not resolve as elbow"
	input.queue_jump()
	input.queue_kick()
	if not input.consume_back_kick_chord():
		return "K then L did not resolve as back kick"

	input.clear_buffered_actions()
	input.queue_attack()
	for _frame: int in range(input.chord_window_frames):
		input.end_physics_tick()
	input.queue_jump()
	if not input.consume_elbow_chord():
		return "Elbow chord rejected its inclusive final input frame"
	input.clear_buffered_actions()
	input.queue_attack()
	for _frame: int in range(input.chord_window_frames + 1):
		input.end_physics_tick()
	input.queue_jump()
	if input.consume_elbow_chord():
		return "Elbow chord accepted input after its window"
	if not input.consume_ready_attack():
		return "Punch single did not fall back after its chord window"
	input.consume_jump()

	input.clear_buffered_actions()
	input.queue_direction_tap(-1.0)
	input.end_physics_tick()
	input.queue_direction_tap(-1.0)
	if input.consume_head_attack_direction() != -1.0:
		return "Rapid LEFT LEFT did not queue a left head attack"
	input.queue_direction_tap(1.0)
	input.end_physics_tick()
	input.queue_direction_tap(1.0)
	if input.consume_head_attack_direction() != 1.0:
		return "Rapid RIGHT RIGHT did not queue a right head attack"

	input.queue_direction_tap(-1.0)
	input.queue_direction_tap(1.0)
	if not is_zero_approx(input.consume_head_attack_direction()):
		return "Opposite direction taps incorrectly triggered head attack"

	input.clear_buffered_actions()
	input.queue_direction_tap(-1.0)
	for _frame: int in range(input.double_tap_window_frames):
		input.end_physics_tick()
	input.queue_direction_tap(-1.0)
	if input.consume_head_attack_direction() != -1.0:
		return "LEFT LEFT rejected its inclusive 12-frame boundary"
	input.clear_buffered_actions()
	input.queue_direction_tap(1.0)
	for _frame: int in range(input.double_tap_window_frames + 1):
		input.end_physics_tick()
	input.queue_direction_tap(1.0)
	if not is_zero_approx(input.consume_head_attack_direction()):
		return "RIGHT RIGHT triggered after its 12-frame window"

	input.clear_buffered_actions()
	var left_event := InputEventAction.new()
	left_event.action = &"move_left"
	left_event.pressed = true
	input._unhandled_input(left_event)
	Input.action_press(&"move_left")
	input.physics_tick()
	Input.action_release(&"move_left")
	if not is_zero_approx(input.consume_head_attack_direction()):
		return "One direction press was double-counted by event plus polling"
	input.end_physics_tick()

	input.clear_buffered_actions()
	var a_press := InputEventKey.new()
	a_press.physical_keycode = KEY_A
	a_press.pressed = true
	var arrow_press := InputEventKey.new()
	arrow_press.physical_keycode = KEY_LEFT
	arrow_press.pressed = true
	input._unhandled_input(a_press)
	input._unhandled_input(arrow_press)
	if not is_zero_approx(input.consume_head_attack_direction()):
		return "Simultaneous A and Left Arrow falsely counted as LEFT LEFT"
	var a_release := a_press.duplicate() as InputEventKey
	a_release.pressed = false
	var arrow_release := arrow_press.duplicate() as InputEventKey
	arrow_release.pressed = false
	input._unhandled_input(a_release)
	input._unhandled_input(arrow_release)
	input.clear_buffered_actions()
	return ""


func _test_pose_schedules(player: Player, attacks: Array) -> String:
	for attack_value: Variant in attacks:
		var attack := attack_value as AttackData
		var frame_count := player.visuals.animated_sprite.sprite_frames.get_frame_count(
			attack.animation_name
		)
		if attack.animation_frame_starts.size() != frame_count:
			return "%s pose schedule count does not match its textures" % attack.attack_name
		if attack.animation_frame_starts[0] != 0:
			return "%s pose schedule must begin at attack frame zero" % attack.attack_name
		var previous_start: int = -1
		for pose_index: int in range(attack.animation_frame_starts.size()):
			var pose_start := attack.animation_frame_starts[pose_index]
			if pose_start <= previous_start or pose_start >= attack.total_frames():
				return "%s has an invalid pose start at index %d" % [
					attack.attack_name,
					pose_index,
				]
			player.visuals.sync(
				PlayerStateMachine.ATTACK,
				Vector2.RIGHT,
				false,
				0.0,
				attack.animation_name,
				pose_start,
				attack.animation_frame_starts,
				attack.animation_facing_multiplier
			)
			if player.visuals.animated_sprite.frame != pose_index:
				return "%s pose %d did not begin on its data frame" % [
					attack.attack_name,
					pose_index,
				]
			if pose_index > 0:
				player.visuals.sync(
					PlayerStateMachine.ATTACK,
					Vector2.RIGHT,
					false,
					0.0,
					attack.animation_name,
					pose_start - 1,
					attack.animation_frame_starts,
					attack.animation_facing_multiplier
				)
				if player.visuals.animated_sprite.frame != pose_index - 1:
					return "%s pose %d began before its data frame" % [
						attack.attack_name,
						pose_index,
					]
			previous_start = pose_start
	return ""


func _test_player_specials(
	player: Player,
	elbow: AttackData,
	head_attack: AttackData,
	back_kick: AttackData,
	jump_kick: AttackData
) -> String:
	_reset_player(player, 1.0)
	player.input_component.queue_attack()
	player.input_component.queue_jump()
	player._physics_process(DELTA)
	if player.combat_component.current_attack_data != elbow:
		return "Grounded J+K did not start elbow"
	if player.jump_component.is_airborne:
		return "Elbow chord incorrectly started a normal jump"
	if player.combat_component.hitbox_shape.position.x >= 0.0:
		return "Right-facing elbow hitbox was not behind Billy"
	if player.visuals.animated_sprite.animation != &"elbow":
		return "Elbow did not select its referenced animation"
	while player.combat_component.attack_frame < elbow.startup_frames:
		player._physics_process(DELTA)
	if not player.combat_component.is_hitbox_active:
		return "Elbow did not enter its active window"
	if player.visuals.animated_sprite.frame != 1:
		return "Active elbow did not show the strike pose"
	_reset_player(player, -1.0)
	if not player.combat_component.try_start_attack(elbow):
		return "Left-facing rear-elbow geometry setup did not start"
	if player.combat_component.hitbox_shape.position.x <= 0.0:
		return "Left-facing elbow did not place its hitbox behind on the right"
	player.combat_component.cancel_attack()
	player.combat_component.set_facing(1.0)
	if not player.combat_component.try_start_attack(elbow):
		return "Facing-latch cancellation setup did not start"
	player.combat_component.set_facing(-1.0)
	player.combat_component.cancel_attack()
	if not player.combat_component.try_start_attack():
		return "Facing-latch follow-up punch did not start"
	if player.combat_component.attack_facing != 1.0:
		return "Movement input during an attack desynchronized the next facing"
	player.combat_component.cancel_attack()

	_reset_player(player, 1.0)
	if not player.combat_component.try_start_attack(back_kick):
		return "Back-kick cancellation setup did not start"
	player.combat_component.cancel_attack()
	if player.combat_component.attack_facing != 1.0:
		return "Canceling back kick incorrectly reversed Billy"

	_reset_player(player, 1.0)
	player.input_component.queue_kick()
	player.input_component.queue_jump()
	player._physics_process(DELTA)
	if player.combat_component.current_attack_data != back_kick:
		return "Grounded L+K did not start back kick"
	if not player.jump_component.is_airborne:
		return "Back kick did not launch through JumpComponent"
	if player.combat_component.hitbox_shape.position.x >= 0.0:
		return "Right-facing back-kick hitbox was not behind Billy"
	var back_kick_start_x := player.global_position.x
	Input.action_press(&"move_right")
	for _frame: int in range(3):
		player._physics_process(DELTA)
	Input.action_release(&"move_right")
	if player.global_position.x <= back_kick_start_x:
		return "Back kick did not preserve normal belt-plane air control"
	var saw_back_kick_descent: bool = false
	var back_kick_maximum_height := player.jump_component.jump_height
	while player.jump_component.is_airborne:
		player._physics_process(DELTA)
		back_kick_maximum_height = maxf(
			back_kick_maximum_height,
			player.jump_component.jump_height
		)
		if player.jump_component.is_airborne and player.jump_component.jump_velocity < 0.0:
			saw_back_kick_descent = true
			if player.combat_component.current_attack_data != back_kick:
				return "Back kick ended before landing"
			if player.state_machine.current_state != PlayerStateMachine.ATTACK:
				return "Back kick left ATTACK state before landing"
			if player.combat_component.current_phase != CombatComponent.ACTIVE:
				return "Back kick did not remain active through descent"
			if (
				not player.combat_component.is_hitbox_active
				or not player.combat_component.hitbox.monitoring
				or player.combat_component.hitbox_shape.disabled
			):
				return "Back-kick hitbox did not remain physically active through descent"
			if player.visuals.animated_sprite.frame != 3:
				return "Back kick did not hold its extension pose through descent"
			if player.visuals.animated_sprite.flip_h:
				return "Back kick reversed Billy before landing"
	if not saw_back_kick_descent:
		return "Back-kick descent hold was not observed"
	if absf(back_kick_maximum_height - 12.75) > 0.01:
		return "Back kick apex must be one quarter of 51 px; got %.2f" % (
			back_kick_maximum_height
		)
	if player.combat_component.is_attacking:
		return "Back kick did not finish on landing"
	if not player.visuals.animated_sprite.flip_h:
		return "Billy did not face the reverse direction after back kick"
	if not player.combat_component.try_start_attack():
		return "Post-back-kick facing probe could not punch"
	if player.combat_component.attack_facing != -1.0:
		return "Back-kick reversal did not become the next attack's facing"
	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()

	_reset_player(player, 1.0)
	var start_x := player.global_position.x
	player.input_component.queue_direction_tap(-1.0)
	player.input_component.end_physics_tick()
	player.input_component.queue_direction_tap(-1.0)
	player._physics_process(DELTA)
	if player.combat_component.current_attack_data != head_attack:
		return "Rapid LEFT LEFT did not start head attack"
	if player.combat_component.attack_facing != -1.0:
		return "Left head attack did not latch left-facing gameplay direction"
	if not player.visuals.animated_sprite.flip_h:
		return "Left head attack did not mirror the rightward source art"
	if player.visuals.animated_sprite.frame != 0:
		return "Left head attack did not begin on pose 1"
	while player.combat_component.attack_frame < head_attack.startup_frames:
		player._physics_process(DELTA)
	if player.visuals.animated_sprite.frame != 1:
		return "Left head attack did not use pose 2 for its active attack"
	while player.combat_component.attack_frame < (
		head_attack.startup_frames + head_attack.active_frames
	):
		player._physics_process(DELTA)
	if player.visuals.animated_sprite.frame != 2:
		return "Left head attack did not return to pose 1 for recovery"
	if (
		player.visuals.animated_sprite.sprite_frames.get_frame_texture(&"head_attack", 2)
		!= player.visuals.animated_sprite.sprite_frames.get_frame_texture(&"head_attack", 0)
	):
		return "Head-attack ending pose does not reuse pose 1"
	var expected_x := start_x - head_attack.movement_speed * DELTA * float(
		head_attack.movement_end_frame - head_attack.movement_start_frame
	)
	if absf(player.global_position.x - expected_x) > 0.01:
		return "Left head attack traveled %.2f px instead of %.2f px" % [
			start_x - player.global_position.x,
			start_x - expected_x,
		]
	var travel_end_x := player.global_position.x
	player._physics_process(DELTA)
	if absf(player.global_position.x - travel_end_x) > 0.01:
		return "Head attack kept traveling after its data movement window"
	while player.combat_component.is_attacking:
		player._physics_process(DELTA)
	if not player.visuals.animated_sprite.flip_h:
		return "Billy did not return to normal left-facing presentation"

	_reset_player(player, 1.0)
	var right_start_x := player.global_position.x
	player.input_component.queue_direction_tap(1.0)
	player.input_component.end_physics_tick()
	player.input_component.queue_direction_tap(1.0)
	player._physics_process(DELTA)
	if player.combat_component.current_attack_data != head_attack:
		return "Rapid RIGHT RIGHT did not start head attack"
	if player.combat_component.attack_facing != 1.0:
		return "Right head attack did not latch right-facing gameplay direction"
	if player.visuals.animated_sprite.flip_h:
		return "Right head attack incorrectly mirrored the rightward source art"
	if player.visuals.animated_sprite.frame != 0:
		return "Right head attack did not begin on pose 1"
	while player.combat_component.attack_frame < head_attack.startup_frames:
		player._physics_process(DELTA)
	if player.visuals.animated_sprite.frame != 1:
		return "Right head attack did not use pose 2 for its active attack"
	while player.combat_component.attack_frame < (
		head_attack.startup_frames + head_attack.active_frames
	):
		player._physics_process(DELTA)
	if player.visuals.animated_sprite.frame != 2:
		return "Right head attack did not return to pose 1 for recovery"
	var expected_right_x := right_start_x + head_attack.movement_speed * DELTA * float(
		head_attack.movement_end_frame - head_attack.movement_start_frame
	)
	if absf(player.global_position.x - expected_right_x) > 0.01:
		return "Right head attack did not travel exactly rightward"
	while player.combat_component.is_attacking:
		player._physics_process(DELTA)
	if player.state_machine.current_state == PlayerStateMachine.ATTACK:
		return "Right head attack did not return to normal presentation"
	if player.visuals.animated_sprite.flip_h:
		return "Billy did not remain normally facing right after head attack"

	_reset_player(player, 1.0)
	player.jump_component.try_jump()
	var normal_trace: Array[float] = []
	while player.jump_component.is_airborne:
		player._physics_process(DELTA)
		normal_trace.append(player.jump_component.jump_height)

	_reset_player(player, 1.0)
	player.jump_component.try_jump()
	var jump_kick_trace: Array[float] = []
	var jump_tick: int = 0
	var jump_kick_started: bool = false
	var saw_jump_kick_descent: bool = false
	var air_move_start_x := player.global_position.x
	while player.jump_component.is_airborne and jump_tick < 300:
		if jump_tick == 4:
			player.input_component.queue_kick()
			Input.action_press(&"move_right")
		if jump_tick == 7:
			Input.action_release(&"move_right")
		player._physics_process(DELTA)
		jump_kick_trace.append(player.jump_component.jump_height)
		if player.combat_component.current_attack_data == jump_kick:
			jump_kick_started = true
			if player.visuals.animated_sprite.animation != &"jump_kick":
				Input.action_release(&"move_right")
				return "Jump kick was hidden by the normal jump animation"
		if jump_kick_started and player.jump_component.is_airborne:
			if player.combat_component.current_attack_data != jump_kick:
				Input.action_release(&"move_right")
				return "Jump kick ended before landing"
			if player.jump_component.jump_velocity < 0.0:
				saw_jump_kick_descent = true
				if player.state_machine.current_state != PlayerStateMachine.ATTACK:
					Input.action_release(&"move_right")
					return "Jump kick left ATTACK state before landing"
				if player.combat_component.current_phase != CombatComponent.ACTIVE:
					Input.action_release(&"move_right")
					return "Jump kick did not remain active through descent"
				if player.visuals.animated_sprite.frame != 3:
					Input.action_release(&"move_right")
					return "Jump kick did not hold its extension pose through descent"
				if (
					not player.combat_component.is_hitbox_active
					or not player.combat_component.hitbox.monitoring
					or player.combat_component.hitbox_shape.disabled
				):
					Input.action_release(&"move_right")
					return "Jump-kick hitbox did not remain physically active through descent"
		jump_tick += 1
	Input.action_release(&"move_right")
	if jump_tick >= 300 or player.jump_component.is_airborne:
		return "Jump kick did not land through the normal jump arc"
	if not jump_kick_started:
		return "L while airborne did not start jump kick"
	if not saw_jump_kick_descent:
		return "Jump-kick descent hold was not observed"
	if player.combat_component.is_attacking:
		return "Jump kick did not finish on landing"
	if jump_kick_trace != normal_trace:
		return "Jump kick changed the normal jump height/velocity trace"
	if absf(jump_kick_trace.max() - 51.0) > 0.01:
		return "Jump kick changed the 51 px jump apex: %.2f" % jump_kick_trace.max()
	if player.global_position.x <= air_move_start_x:
		return "Jump kick did not preserve normal belt-plane air control"

	for kick_first: bool in [false, true]:
		_reset_player(player, 1.0)
		player.jump_component.try_jump()
		if kick_first:
			player.input_component.queue_kick()
			player.input_component.queue_jump()
		else:
			player.input_component.queue_jump()
			player.input_component.queue_kick()
		player._physics_process(DELTA)
		if player.combat_component.current_attack_data != jump_kick:
			return "Airborne K+L order did not resolve to jump kick"

	_reset_player(player, 1.0)
	player.jump_component.try_jump()
	while true:
		var next_velocity := (
			player.jump_component.jump_velocity
			- player.fighter_stats.jump_gravity * DELTA
		)
		var next_height := player.jump_component.jump_height + next_velocity * DELTA
		if next_height <= 0.0:
			break
		player.jump_component.physics_tick(DELTA)
	player.input_component.queue_kick()
	player._physics_process(DELTA)
	if player.combat_component.is_attacking:
		return "L on the landing integration tick incorrectly started jump kick"
	for _frame: int in range(player.input_component.chord_window_frames + 1):
		player._physics_process(DELTA)
	if player.combat_component.current_attack_data != player.kick_attack_data:
		return "Landing-tick L did not fall back to the grounded basic kick"
	return ""


# Real actor integration: no reaction ticks may hide a delayed first-hit pose.
func _test_williams_special_falls(player: Player, attacks: Array) -> String:
	for attack: AttackData in attacks:
		for facing: float in [1.0, -1.0]:
			for lethal: bool in [false, true]:
				var error := await _test_williams_special_fall(player, attack, facing, lethal)
				if not error.is_empty():
					return "%s facing=%s lethal=%s: %s" % [attack.attack_name, facing, lethal, error]
	return ""


func _test_williams_special_fall(
	player: Player, attack: AttackData, facing: float, lethal: bool
) -> String:
	_reset_player(player, facing)
	var victim := WILLIAMS_SCENE.instantiate() as Williams
	victim.acquire_player_target = false
	victim.position = player.global_position + Vector2(28.0 * facing * attack.hit_direction_multiplier, 0.0)
	root.add_child(victim)
	victim.set_physics_process(false)
	# Native fall art points LEFT. The correct reaction facing is -fall direction;
	# seed the opposite so stale AI facing cannot accidentally pass.
	victim.ai_component.facing = facing
	victim.combat_component.set_facing(facing)
	victim._sync_visuals()
	if lethal:
		victim.health_component.current_health = attack.damage
	var initial_health := victim.health_component.current_health
	var initial_position := victim.global_position
	var payloads: Array[Dictionary] = []
	var capture := func(target: HurtboxComponent, data: AttackData, knockback: Vector2) -> void:
		payloads.append({"target": target, "attack": data, "knockback": knockback})
	player.combat_component.hit_landed.connect(capture)
	await physics_frame
	var error := ""
	if not player.combat_component.try_start_attack(attack):
		error = "Could not start special attack"
	else:
		for _frame: int in range(attack.startup_frames + attack.active_frames + 2):
			player.combat_component.physics_tick(attack != player.elbow_attack_data)
			if not payloads.is_empty():
				break
			await physics_frame
		var expected_reaction := HitReactionComponent.DEATH if lethal else HitReactionComponent.KNOCKDOWN
		var expected_state := EnemyStateMachine.DEAD if lethal else EnemyStateMachine.KNOCKDOWN
		var sprite := victim.visuals.animated_sprite
		if payloads.size() != 1:
			error = "Expected exactly one physical first hit"
		elif payloads[0]["target"] != victim.hurtbox or payloads[0]["attack"] != attack:
			error = "hit_landed lost its victim or AttackData payload"
		elif not (payloads[0]["knockback"] as Vector2).is_equal_approx(Vector2(absf(attack.knockback.x) * facing, attack.knockback.y)):
			error = "Hit payload must pull rear victims toward Billy / push front victims away"
		elif victim.health_component.current_health != initial_health - attack.damage:
			error = "First hit applied incorrect damage"
		elif victim.hit_reaction_component.current_reaction != expected_reaction or victim.state_machine.current_state != expected_state:
			error = "First hit did not immediately enter %s" % expected_reaction
		elif not victim.hurtbox.is_invulnerable:
			error = "Falling victim was not immediately invulnerable"
		elif victim.hit_reaction_component.reaction_frame != 0 or sprite.animation != expected_reaction or sprite.frame != 0:
			error = "First hit did not immediately display the initial fall pose"
		elif victim.ai_component.facing != -facing or sprite.flip_h != (facing > 0.0):
			error = "Reaction retained inconsistent AI facing or mirrored LEFT-falling art incorrectly"
		else:
			victim._physics_process(DELTA)
			var displacement := victim.global_position - initial_position
			var old_distance := absf(initial_position.x - player.global_position.x)
			var new_distance := absf(victim.global_position.x - player.global_position.x)
			if displacement.x * facing <= 0.0 or not is_zero_approx(displacement.y):
				error = "Actual fall displacement did not follow the hit payload"
			elif attack.hit_direction_multiplier < 0 and new_distance >= old_distance:
				error = "Rear victim did not move toward Billy"
			elif attack.hit_direction_multiplier > 0 and new_distance <= old_distance:
				error = "Jump-kick victim did not move away from Billy"
	player.combat_component.hit_landed.disconnect(capture)
	player.combat_component.cancel_attack()
	victim.queue_free()
	await physics_frame
	return error


func _test_rear_physical_hits(
	player: Player,
	elbow: AttackData,
	back_kick: AttackData
) -> String:
	for facing: float in [1.0, -1.0]:
		var error := await _test_rear_physical_hits_facing(player, elbow, back_kick, facing)
		if not error.is_empty():
			return error
	return ""


func _test_rear_physical_hits_facing(
	player: Player, elbow: AttackData, back_kick: AttackData, facing: float
) -> String:
	_reset_player(player, facing)
	var target := Node2D.new()
	target.global_position = player.global_position
	var health := HealthComponent.new()
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	collision.position = Vector2(-24.0 * facing, -30.0)
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

	var front_target := Node2D.new()
	front_target.global_position = player.global_position
	var front_health := HealthComponent.new()
	var front_hurtbox := HurtboxComponent.new()
	var front_collision := CollisionShape2D.new()
	var front_shape := RectangleShape2D.new()
	front_shape.size = Vector2(18.0, 18.0)
	front_collision.shape = front_shape
	front_collision.position = Vector2(24.0 * facing, -30.0)
	front_hurtbox.collision_layer = 8
	front_hurtbox.collision_mask = 0
	front_hurtbox.monitoring = false
	front_hurtbox.add_child(front_collision)
	front_hurtbox.health_component = front_health
	front_target.add_child(front_health)
	front_target.add_child(front_hurtbox)
	var front_stats := FighterStats.new()
	front_health.configure(front_stats)
	root.add_child(front_target)
	await physics_frame

	var knockbacks: Array[Vector2] = []
	var capture := func(_target: HurtboxComponent, _attack: AttackData, knockback: Vector2) -> void:
		knockbacks.append(knockback)
	player.combat_component.hit_landed.connect(capture)
	if not player.combat_component.try_start_attack(elbow):
		return "Physical rear-elbow setup did not start"
	for _frame: int in range(elbow.startup_frames + elbow.active_frames):
		player.combat_component.physics_tick()
		await physics_frame
	if health.current_health != stats.max_health - elbow.damage:
		return "Physical enemy behind Billy was not hit exactly once by elbow"
	if front_health.current_health != front_stats.max_health:
		return "Elbow incorrectly hit the enemy in front of Billy"
	if knockbacks.size() != 1 or knockbacks[0].x * facing <= 0.0:
		return "Rear elbow did not knock its target toward Billy"

	player.combat_component.cancel_attack()
	await process_frame
	if not player.combat_component.try_start_attack(back_kick):
		return "Physical rear back-kick setup did not start"
	for _frame: int in range(back_kick.startup_frames + back_kick.active_frames):
		player.combat_component.physics_tick(true)
		await physics_frame
	if health.current_health != stats.max_health - elbow.damage - back_kick.damage:
		return "Physical enemy behind Billy was not hit exactly once by back kick"
	if front_health.current_health != front_stats.max_health:
		return "Back kick incorrectly hit the enemy in front of Billy"
	if knockbacks.size() != 2 or knockbacks[1].x * facing <= 0.0:
		return "Rear back kick did not knock its target toward Billy"

	player.combat_component.cancel_attack()
	player.combat_component.hit_landed.disconnect(capture)
	target.queue_free()
	front_target.queue_free()
	await physics_frame
	return ""


func _test_head_final_active_hit(player: Player, head_attack: AttackData) -> String:
	_reset_player(player, 1.0)
	var start_x := player.global_position.x
	var target := Node2D.new()
	target.global_position = player.global_position
	var health := HealthComponent.new()
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	# The target begins beyond every earlier active-frame reach. Only frame 9's
	# final 2 px lunge puts the right edge of the hitbox into this hurtbox.
	collision.position = Vector2(66.0, -33.0)
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

	player.combat_component.set_facing(1.0)
	if not player.combat_component.try_start_attack(head_attack):
		return "Final-active head-attack setup did not start"
	for _frame: int in range(head_attack.movement_end_frame):
		player._physics_process(DELTA)
		await physics_frame
	if absf(player.global_position.x - (start_x + 20.0)) > 0.01:
		return "Final-active head-attack setup did not travel exactly 20 px"
	if health.current_health != stats.max_health - head_attack.damage:
		return "Head attack missed a target reached only on its final active movement frame"

	player.combat_component.cancel_attack()
	target.queue_free()
	await physics_frame
	return ""


func _test_jump_kick_physical_hit(player: Player, jump_kick: AttackData) -> String:
	_reset_player(player, 1.0)
	player.jump_component.try_jump()
	var target := Node2D.new()
	target.global_position = player.global_position
	var health := HealthComponent.new()
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	collision.position = Vector2(28.0, -34.0)
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

	if not player.combat_component.try_start_attack(jump_kick):
		return "Physical jump-kick setup did not start"
	for _frame: int in range(jump_kick.startup_frames + jump_kick.active_frames):
		player.combat_component.physics_tick(true)
		await physics_frame
	if health.current_health != stats.max_health - jump_kick.damage:
		return "Physical jump kick did not damage its target exactly once"
	for _frame: int in range(20):
		player.combat_component.physics_tick(true)
		await physics_frame
	if health.current_health != stats.max_health - jump_kick.damage:
		return "Landing-held jump kick damaged the same target more than once"

	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()
	target.queue_free()
	await physics_frame
	return ""


func _test_reentrant_attack_replacement(
	player: Player,
	elbow: AttackData,
	back_kick: AttackData
) -> String:
	_reset_player(player, 1.0)
	var restarted: Array[bool] = [false]
	var nested_start_result: Array[bool] = [false]
	var started_count: Array[int] = [0]
	var finished_count: Array[int] = [0]
	var phase_listener := func(_previous: StringName, current: StringName) -> void:
		if current == CombatComponent.STARTUP and not restarted[0]:
			restarted[0] = true
			player.combat_component.cancel_attack()
			nested_start_result[0] = player.combat_component.try_start_attack(elbow)
	var started_listener := func() -> void: started_count[0] += 1
	var finished_listener := (
		func(_attack: AttackData, _naturally: bool) -> void: finished_count[0] += 1
	)
	player.combat_component.attack_phase_changed.connect(phase_listener)
	player.combat_component.attack_started.connect(started_listener)
	player.combat_component.attack_finished.connect(finished_listener)
	var outer_start_result := player.combat_component.try_start_attack(elbow)
	player.combat_component.attack_phase_changed.disconnect(phase_listener)
	player.combat_component.attack_started.disconnect(started_listener)
	player.combat_component.attack_finished.disconnect(finished_listener)
	if outer_start_result or not nested_start_result[0]:
		return "Re-entrant startup replacement returned the wrong start results"
	if started_count[0] != 1 or finished_count[0] != 1:
		return "Re-entrant startup replacement double-emitted lifecycle signals"
	if player.combat_component.current_attack_data != elbow:
		return "Re-entrant startup replacement did not preserve the new attack"
	player.combat_component.cancel_attack()

	_reset_player(player, 1.0)
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

	var replacement_started: Array[bool] = [false]
	var finished_attacks: Array[StringName] = []
	var finish_capture := func(attack: AttackData, naturally: bool) -> void:
		finished_attacks.append(
			&"natural" if naturally else attack.attack_name
		)
	player.combat_component.attack_finished.connect(finish_capture)
	hurtbox.hit_received.connect(
		func(_attack: AttackData, _knockback: Vector2, _source: Node2D) -> void:
			player.combat_component.cancel_attack()
			replacement_started[0] = player.combat_component.try_start_attack(back_kick)
			player.jump_component.try_jump(),
		CONNECT_ONE_SHOT
	)
	if not player.combat_component.try_start_attack():
		return "Stale-tick replacement setup did not start punch"
	for _frame: int in range(player.combat_component.attack_data.startup_frames):
		player.combat_component.physics_tick(false)
	player.combat_component.physics_tick(false)
	player.combat_component.attack_finished.disconnect(finish_capture)
	if not replacement_started[0] or not player.jump_component.is_airborne:
		return "Hit callback did not create the replacement aerial back kick"
	if (
		not player.combat_component.is_attacking
		or player.combat_component.current_attack_data != back_kick
	):
		return "Stale combat tick finished the replacement back kick"
	if player.combat_component.attack_facing != 1.0:
		return "Stale combat tick reversed the replacement back kick"
	if finished_attacks != [&"billy_punch"]:
		return "Stale combat tick emitted a natural finish for the replacement"

	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()
	target.queue_free()
	await physics_frame
	return ""


func _test_no_post_landing_hit(player: Player, jump_kick: AttackData) -> String:
	_reset_player(player, 1.0)
	var target := Node2D.new()
	target.global_position = player.global_position + Vector2(1000.0, 0.0)
	var health := HealthComponent.new()
	var hurtbox := HurtboxComponent.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	collision.position = Vector2(28.0, -34.0)
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

	player.jump_component.landed.connect(
		func() -> void: target.global_position = player.global_position,
		CONNECT_ONE_SHOT
	)
	player.jump_component.try_jump()
	if not player.combat_component.try_start_attack(jump_kick):
		return "Post-landing hit setup did not start jump kick"
	while player.jump_component.is_airborne:
		player._physics_process(DELTA)
	if player.combat_component.is_attacking:
		return "Jump kick remained active after landing"
	if health.current_health != stats.max_health:
		return "Jump kick produced a new hit after landing"

	target.queue_free()
	await physics_frame
	return ""


func _test_back_kick_death_cancellation() -> String:
	var victim := PLAYER_SCENE.instantiate() as Player
	root.add_child(victim)
	await physics_frame
	victim.set_physics_process(false)
	victim.combat_component.set_facing(1.0)
	victim.visuals.set_facing(1.0)
	victim.input_component.queue_kick()
	victim.input_component.queue_jump()
	victim._physics_process(DELTA)
	if victim.combat_component.current_attack_data != victim.back_kick_attack_data:
		return "Death-cancellation setup did not start back kick"
	victim.health_component.take_damage(victim.health_component.current_health)
	if victim.state_machine.current_state != PlayerStateMachine.DEAD:
		return "Lethal damage did not enter DEAD during back kick"
	if victim.combat_component.is_attacking:
		return "Death did not cancel landing-held back kick"
	if victim.combat_component.attack_facing != 1.0:
		return "Death cancellation incorrectly reversed back-kick facing"

	victim.queue_free()
	await physics_frame
	return ""


func _test_reentrant_hit_cancellation(player: Player) -> String:
	_reset_player(player, 1.0)
	var started_count: Array[int] = [0]
	var finished_count: Array[int] = [0]
	var phase_listener := func(_previous: StringName, current: StringName) -> void:
		if current == CombatComponent.STARTUP or current == CombatComponent.INACTIVE:
			player.combat_component.cancel_attack()
	var started_listener := func() -> void: started_count[0] += 1
	var finished_listener := (
		func(_attack: AttackData, _naturally: bool) -> void: finished_count[0] += 1
	)
	player.combat_component.attack_phase_changed.connect(phase_listener)
	player.combat_component.attack_started.connect(started_listener)
	player.combat_component.attack_finished.connect(finished_listener)
	var start_result := player.combat_component.try_start_attack()
	player.combat_component.attack_phase_changed.disconnect(phase_listener)
	player.combat_component.attack_started.disconnect(started_listener)
	player.combat_component.attack_finished.disconnect(finished_listener)
	if start_result or player.combat_component.is_attacking:
		return "Startup-phase cancellation did not abort attack entry"
	if started_count[0] != 0 or finished_count[0] != 1:
		return "Re-entrant lifecycle signals emitted started/finished incorrectly"

	_reset_player(player, 1.0)
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

	var landed_attacks: Array[AttackData] = []
	hurtbox.hit_received.connect(
		func(_attack: AttackData, _knockback: Vector2, _source: Node2D) -> void:
			player.combat_component.cancel_attack(),
		CONNECT_ONE_SHOT
	)
	player.combat_component.hit_landed.connect(
		func(_target: HurtboxComponent, attack: AttackData, _knockback: Vector2) -> void:
			landed_attacks.append(attack),
		CONNECT_ONE_SHOT
	)
	if not player.combat_component.try_start_attack():
		return "Re-entrant cancellation setup did not start punch"
	for _frame: int in range(player.combat_component.attack_data.startup_frames + 1):
		player.combat_component.physics_tick()
		await physics_frame
	if player.combat_component.is_attacking:
		return "Hit listener did not cancel attack re-entrantly"
	if health.current_health != stats.max_health - player.combat_component.attack_data.damage:
		return "Re-entrant cancellation changed hit delivery"
	if landed_attacks.size() != 1 or landed_attacks[0] != player.combat_component.attack_data:
		return "Target-side cancellation corrupted the hit_landed AttackData payload"

	target.queue_free()
	await physics_frame
	return ""


func _reset_player(player: Player, facing: float) -> void:
	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()
	player.input_component.clear_buffered_actions()
	player.combat_component.set_facing(facing)
	player.visuals.set_facing(facing)
	player.state_machine.transition_to(PlayerStateMachine.IDLE)


func _fail(message: String) -> void:
	push_error("SPECIAL_MOVES_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
