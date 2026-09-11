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

	var expected_animations: Array[StringName] = [
		&"idle",
		&"walk_up",
		&"walk_down",
		&"punch",
		&"hurt",
		&"knockdown",
		&"death",
	]
	var sprite_frames := player.visuals.animated_sprite.sprite_frames
	for animation_name: StringName in expected_animations:
		if not sprite_frames.has_animation(animation_name):
			_fail("Missing player animation: %s" % animation_name)
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
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.RIGHT)

	var starting_position := player.global_position
	Input.action_press(&"move_right")
	for _frame: int in range(4):
		await physics_frame
	Input.action_release(&"move_right")

	if player.global_position.x <= starting_position.x:
		_fail("Player did not move right through MovementComponent")
		return

	Input.action_press(&"attack")
	for _frame: int in range(2):
		await physics_frame
	Input.action_release(&"attack")

	if not player.combat_component.is_attacking:
		_fail("Player did not enter the attack through InputComponent")
		return
	if player.state_machine.current_state != PlayerStateMachine.ATTACK:
		_fail("Player state machine did not enter ATTACK")
		return

	for _frame: int in range(player.combat_component.attack_duration_frames + 1):
		await physics_frame

	if player.combat_component.is_attacking:
		_fail("CombatComponent did not finish its attack")
		return
	if player.state_machine.current_state != PlayerStateMachine.IDLE:
		_fail("Player state machine did not return to IDLE")
		return

	print("PLAYER_SMOKE_TEST_PASS")
	quit()


func _fail(message: String) -> void:
	push_error("PLAYER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
