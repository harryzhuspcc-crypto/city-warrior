extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	if player == null:
		_fail("Player scene did not instantiate as Player")
		return

	root.add_child(player)
	await physics_frame
	if player.health_component.current_health != player.fighter_stats.max_health:
		_fail("HealthComponent did not initialize from FighterStats")
		return
	if not InputMap.has_action(&"kick"):
		_fail("Missing semantic kick action")
		return
	var punch_uses_j: bool = false
	for event: InputEvent in InputMap.action_get_events(&"attack"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_J:
			punch_uses_j = true
	if not punch_uses_j:
		_fail("Punch action must remain on the J key")
		return
	var kick_uses_l: bool = false
	for event: InputEvent in InputMap.action_get_events(&"kick"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_L:
			kick_uses_l = true
	if not kick_uses_l:
		_fail("Kick action must use the L key")
		return
	for event: InputEvent in InputMap.action_get_events(&"grab"):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == KEY_L:
			_fail("L must not trigger both kick and grab")
			return

	var expected_animations: Array[StringName] = [
		&"idle",
		&"walk_up",
		&"walk_down",
		&"jump",
		&"punch",
		&"kick",
		&"hurt",
		&"knockdown",
		&"death",
	]
	var sprite_frames := player.visuals.animated_sprite.sprite_frames
	for animation_name: StringName in expected_animations:
		if not sprite_frames.has_animation(animation_name):
			_fail("Missing player animation: %s" % animation_name)
			return
	if sprite_frames.get_frame_count(&"kick") != 2:
		_fail("Kick animation must contain exactly two referenced poses")
		return
	if not sprite_frames.get_frame_texture(&"kick", 0).resource_path.ends_with("kick_00.png"):
		_fail("Kick chamber texture is not the first referenced pose")
		return
	if not sprite_frames.get_frame_texture(&"kick", 1).resource_path.ends_with("kick_01.png"):
		_fail("Kick extension texture is not the second referenced pose")
		return

	player.visuals.sync(PlayerStateMachine.MOVE, Vector2.RIGHT)
	if player.visuals.animated_sprite.animation != &"walk_down":
		_fail("Horizontal movement must use the same walk_down animation as Down")
		return
	if player.visuals.animated_sprite.flip_h:
		_fail("Right movement must face right")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2.LEFT)
	if player.visuals.animated_sprite.animation != &"walk_down":
		_fail("Left movement must use walk_down")
		return
	if not player.visuals.animated_sprite.flip_h:
		_fail("Left movement must face left")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2.UP)
	if player.visuals.animated_sprite.animation != &"walk_up":
		_fail("Upward movement must use walk_up")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2.DOWN)
	if player.visuals.animated_sprite.animation != &"walk_down":
		_fail("Downward movement must use walk_down")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2(1.0, -0.25))
	if player.visuals.animated_sprite.animation != &"walk_down":
		_fail("Horizontal-dominant diagonal movement must use walk_down")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2(0.25, -1.0))
	if player.visuals.animated_sprite.animation != &"walk_up":
		_fail("Upward-dominant diagonal movement must use walk_up")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2(-1.0, -1.0))
	if not player.visuals.animated_sprite.flip_h:
		_fail("Up-left movement must face left")
		return
	var retained_animation := player.visuals.animated_sprite.animation
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.ZERO)
	if player.visuals.animated_sprite.animation != retained_animation:
		_fail("Neutral input must retain the previous locomotion view")
		return
	if not player.visuals.animated_sprite.flip_h:
		_fail("Neutral input must retain left-facing orientation")
		return
	if player.visuals.animated_sprite.is_playing():
		_fail("Retained neutral locomotion pose must not keep walking")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2(-1.0, -1.0))
	if not player.visuals.animated_sprite.is_playing():
		_fail("Moving again in the retained direction must resume animation playback")
		return
	player.visuals.sync(PlayerStateMachine.MOVE, Vector2(-1.0, 1.0))
	if player.visuals.animated_sprite.animation != &"walk_down":
		_fail("Down-left movement must use walk_down")
		return
	if not player.visuals.animated_sprite.flip_h:
		_fail("Down-left movement must face left")
		return
	retained_animation = player.visuals.animated_sprite.animation
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.ZERO)
	if player.visuals.animated_sprite.animation != retained_animation:
		_fail("Neutral input must retain the previous down-left view")
		return
	if not player.visuals.animated_sprite.flip_h:
		_fail("Neutral input after down-left must retain left-facing orientation")
		return
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.RIGHT)

	var starting_position := player.global_position
	Input.action_press(&"move_right")
	for _frame: int in range(4):
		await physics_frame
	Input.action_release(&"move_right")

	if player.global_position.x <= starting_position.x:
		_fail("Player did not move right through MovementComponent")
		return

	player.input_component.queue_attack()
	for _frame: int in range(player.input_component.chord_window_frames + 2):
		await physics_frame

	if not player.combat_component.is_attacking:
		_fail("Player did not enter the attack through InputComponent")
		return
	if player.state_machine.current_state != PlayerStateMachine.ATTACK:
		_fail("Player state machine did not enter ATTACK")
		return

	for _frame: int in range(player.combat_component.attack_data.total_frames() + 1):
		await physics_frame

	if player.combat_component.is_attacking:
		_fail("CombatComponent did not finish its attack")
		return
	if player.state_machine.current_state != PlayerStateMachine.IDLE:
		_fail("Player state machine did not return to IDLE")
		return

	player.input_component.queue_kick()
	for _frame: int in range(player.input_component.chord_window_frames + 2):
		await physics_frame
	if not player.combat_component.is_attacking:
		_fail("L did not start the kick through InputComponent")
		return
	if player.combat_component.current_attack_data != player.kick_attack_data:
		_fail("Kick input did not select Billy's kick AttackData")
		return
	if player.visuals.animated_sprite.animation != &"kick":
		_fail("Kick attack did not select the kick animation")
		return
	if player.visuals.animated_sprite.frame != 0:
		_fail("Kick startup did not use the chamber pose")
		return
	while (
		player.combat_component.is_attacking
		and player.combat_component.attack_frame
		< player.combat_component.current_attack_data.startup_frames
	):
		await physics_frame
	if not player.combat_component.is_hitbox_active:
		_fail("Kick did not enter its active hitbox window")
		return
	if player.visuals.animated_sprite.frame != 1:
		_fail("Active kick did not use the high-extension pose")
		return
	player.input_component.queue_jump()
	for _frame: int in range(player.input_component.chord_window_frames + 2):
		await physics_frame
	var kick_total_frames: int = player.combat_component.current_attack_data.total_frames()
	for _frame: int in range(kick_total_frames + 1):
		await physics_frame
	if player.combat_component.is_attacking:
		_fail("Kick did not finish from its AttackData timing")
		return
	if player.jump_component.is_airborne:
		_fail("Jump pressed early during kick must not latch through the full attack")
		return

	player.input_component.queue_jump()
	for _frame: int in range(player.input_component.chord_window_frames + 2):
		await physics_frame
	if not player.jump_component.is_airborne:
		_fail("Airborne attack regression setup did not jump")
		return
	player.input_component.queue_kick()
	for _frame: int in range(2):
		await physics_frame
	if player.combat_component.current_attack_data != player.jump_kick_attack_data:
		_fail("Kick pressed while airborne must start jump kick")
		return
	if player.visuals.animated_sprite.animation != &"jump_kick":
		_fail("Jump kick must override the normal jump presentation")
		return
	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()
	player.input_component.clear_buffered_actions()

	print("PLAYER_SMOKE_TEST_PASS")
	quit()


func _fail(message: String) -> void:
	push_error("PLAYER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
