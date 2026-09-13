extends SceneTree
## Billy's hit-confirmed combo chains: the three-hit punch and the three-hit
## kick from plan Section 9. The first two connected inputs advance the chain
## and only the third uses the finisher, so every slice here drives real
## attacks against a real hurtbox rather than asserting on button presses.

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")
const WILLIAMS_SCENE: PackedScene = preload("res://features/actors/enemies/williams/williams.tscn")
const DELTA: float = 1.0 / 60.0
## Wide enough for the punch's chest reach and the uppercut's overhead swing.
const TARGET_HURTBOX_SIZE: Vector2 = Vector2(26.0, 64.0)
const TARGET_HURTBOX_OFFSET: Vector2 = Vector2(20.0, -36.0)
const ENEMY_HURTBOX_LAYER: int = 8
## Far enough that no chain step can reach, without leaving the level.
const OUT_OF_REACH_X: float = 220.0
## Puts a Williams inside the reach of both finishers.
const WILLIAMS_OFFSET_X: float = 16.0
## Billy's own reach for the opening step of either chain.
const SPARRING_OFFSET_X: float = 26.0

var _last_attack: AttackData
var _last_attack_animation: StringName = &""
var _last_attack_landed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await physics_frame
	player.set_physics_process(false)
	var target := _make_target(player.global_position)
	root.add_child(target)
	await physics_frame

	for slice: Callable in [
		_test_a_confirmed_hit_advances_the_chain,
		_test_three_connected_punches,
		_test_a_whiff_does_not_advance_the_chain,
		_test_the_chain_closes_after_its_window,
		_test_an_interrupted_attack_breaks_the_chain,
		_test_mixing_punches_and_kicks_breaks_the_chain,
		_test_three_connected_kicks,
		_test_the_chain_reaches_a_knocked_back_target,
		_test_the_chain_art_and_data,
	]:
		var error: String = await slice.call(player, target)
		if not error.is_empty():
			_fail(error)
			return

	var knockdown_error := await _test_each_finisher_knocks_down(player)
	if not knockdown_error.is_empty():
		_fail(knockdown_error)
		return

	print("COMBO_SMOKE_TEST_PASS")
	quit()


## Landing a punch must move the chain onto its second step; the step itself
## is the attack the chain hands out, never a flag the player keeps.
func _test_a_confirmed_hit_advances_the_chain(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var chain := player.punch_chain
	if chain.size() != 3:
		return "Billy's punch chain must have three steps, got %d" % chain.size()
	var chain_component := player.attack_chain_component
	if chain_component.next_attack(chain) != chain[0]:
		return "A fresh chain must hand out its first step"
	if chain_component.is_open():
		return "A chain on its opener is not yet a combo"

	var error := await _run_one_attack(player)
	if not error.is_empty():
		return error
	if not _last_attack_landed:
		return "Setup: the opening punch must reach the target"
	if chain_component.index != 1:
		return "A connected punch must advance the chain, index is %d" % chain_component.index
	if not chain_component.is_open():
		return "The chain must stay open after a connected hit"
	if chain_component.next_attack(chain) != chain[1]:
		return "The second step must be the cross"
	return ""


## Three connected punches play punch, cross, then the rising finisher, and
## the chain starts over once the finisher has landed.
func _test_three_connected_punches(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var chain := player.punch_chain
	var expected_animations: Array[StringName] = [&"punch", &"punch_cross", &"uppercut"]
	for step: int in range(3):
		var error := await _run_one_attack(player)
		if not error.is_empty():
			return "Punch %d: %s" % [step + 1, error]
		if not _last_attack_landed:
			return "Punch %d must connect for the chain to advance" % [step + 1]
		if _last_attack != chain[step]:
			return "Punch %d used %s instead of the chain's step" % [
				step + 1,
				_last_attack.attack_name,
			]
		if _last_attack_animation != expected_animations[step]:
			return "Punch %d presented %s instead of %s" % [
				step + 1,
				_last_attack_animation,
				expected_animations[step],
			]
	if player.attack_chain_component.index != 0:
		return "The finisher must spend the chain and start it over"
	if player.attack_chain_component.is_open():
		return "A spent chain must not stay open"
	return ""


## The chain is earned, not counted: a punch that hits nothing leaves the next
## press back on the opener.
func _test_a_whiff_does_not_advance_the_chain(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	await _move_target(target, player.global_position.x + OUT_OF_REACH_X)
	var error := await _run_one_attack(player)
	if not error.is_empty():
		return error
	if _last_attack_landed:
		return "Setup: the whiff slice must not reach the target"
	if player.attack_chain_component.index != 0:
		return "A whiffed punch advanced the chain"

	# A whiff after a connected opener drops the chain too, so the cross that
	# missed cannot be followed by the finisher.
	await _move_target(target, player.global_position.x)
	error = await _run_one_attack(player)
	if not error.is_empty():
		return error
	if player.attack_chain_component.index != 1:
		return "Setup: the opener must land before the second whiff"
	await _move_target(target, player.global_position.x + OUT_OF_REACH_X)
	error = await _run_one_attack(player)
	if not error.is_empty():
		return error
	if _last_attack != player.punch_chain[1]:
		return "The second press must still use the cross"
	if player.attack_chain_component.index != 0:
		return "A whiffed cross must drop the chain back to its opener"
	await _move_target(target, player.global_position.x)
	return ""


## Waiting too long between steps closes the chain.
func _test_the_chain_closes_after_its_window(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var error := await _run_one_attack(player)
	if not error.is_empty():
		return error
	if player.attack_chain_component.index != 1:
		return "Setup: the opener must land"
	var window := player.attack_chain_component.open_frames
	for _frame: int in range(window - 1):
		player._physics_process(DELTA)
	if player.attack_chain_component.index != 1:
		return "The chain closed before its window elapsed"
	player._physics_process(DELTA)
	if player.attack_chain_component.index != 0:
		return "The chain stayed open past its window"
	return ""


## Being hit mid-combo breaks it.
func _test_an_interrupted_attack_breaks_the_chain(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var error := await _run_one_attack(player)
	if not error.is_empty():
		return error
	if player.attack_chain_component.index != 1:
		return "Setup: the opener must land"

	player.input_component.queue_attack()
	for _frame: int in range(12):
		player._physics_process(DELTA)
		await physics_frame
		if player.combat_component.is_attacking:
			break
	if not player.combat_component.is_attacking:
		return "Setup: the cross must start before the interruption"
	var incoming := load("res://features/combat/williams_punch.tres") as AttackData
	player.hurtbox.receive_attack(incoming, Vector2(-40.0, 0.0), target)
	if player.combat_component.is_attacking:
		return "Setup: the incoming hit must cancel the cross"
	if player.attack_chain_component.index != 0:
		return "An interrupted step must break the chain"
	return ""


## Switching weapons mid-combo starts the other chain from its opener.
func _test_mixing_punches_and_kicks_breaks_the_chain(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var error := await _run_one_attack(player)
	if not error.is_empty():
		return error
	if player.attack_chain_component.index != 1:
		return "Setup: the opener must land"

	error = await _run_one_attack(player, true)
	if not error.is_empty():
		return error
	if _last_attack != player.kick_chain[0]:
		return "A kick after a punch must open the kick chain, got %s" % _last_attack.attack_name
	if player.attack_chain_component.index != 1:
		return "The connected kick must open its own chain"
	if player.attack_chain_component.next_attack(player.punch_chain) != player.punch_chain[0]:
		return "Returning to punches must start that chain over"
	return ""


## The kick chain opens twice with the basic kick, because the sheet authors
## only one, and finishes on the turning kick.
func _test_three_connected_kicks(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	var chain := player.kick_chain
	if chain.size() != 3:
		return "Billy's kick chain must have three steps, got %d" % chain.size()
	var expected_animations: Array[StringName] = [&"kick", &"kick", &"turn_kick"]
	for step: int in range(3):
		var error := await _run_one_attack(player, true)
		if not error.is_empty():
			return "Kick %d: %s" % [step + 1, error]
		if not _last_attack_landed:
			return "Kick %d must connect for the chain to advance" % [step + 1]
		if _last_attack != chain[step]:
			return "Kick %d used %s instead of the chain's step" % [
				step + 1,
				_last_attack.attack_name,
			]
		if _last_attack_animation != expected_animations[step]:
			return "Kick %d presented %s instead of %s" % [
				step + 1,
				_last_attack_animation,
				expected_animations[step],
			]
	if player.attack_chain_component.index != 0:
		return "The turning finisher must spend the kick chain"
	return ""


## The chains are made of the art the references show, and each finisher is
## reached only as a third step.
func _test_the_chain_art_and_data(player: Player, _target: Node2D) -> String:
	var frames := player.visuals.animated_sprite.sprite_frames
	for contract: Array in [
		[&"punch_cross", 3],
		[&"uppercut", 4],
		[&"turn_kick", 5],
	]:
		var animation_name := contract[0] as StringName
		var expected_count := contract[1] as int
		if not frames.has_animation(animation_name):
			return "Missing chain animation: %s" % animation_name
		if frames.get_frame_count(animation_name) != expected_count:
			return "%s must contain exactly %d poses" % [animation_name, expected_count]
		for frame_index: int in range(expected_count):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			if not texture.resource_path.ends_with("%s_%02d.png" % [
				animation_name,
				frame_index,
			]):
				return "%s pose %d has the wrong source texture" % [
					animation_name,
					frame_index,
				]

	if player.punch_chain[0] != player.combat_component.attack_data:
		return "The punch chain must open with Billy's basic punch"
	if player.kick_chain[0] != player.kick_attack_data:
		return "The kick chain must open with Billy's basic kick"
	if player.kick_chain[1] != player.kick_attack_data:
		return "The kick chain's second step must reuse the basic kick"
	var finishers: Array[AttackData] = [player.punch_chain[2], player.kick_chain[2]]
	for finisher: AttackData in finishers:
		if not finisher.knocks_down:
			return "%s must knock its target down" % finisher.attack_name
	for chain: Array in [player.punch_chain, player.kick_chain]:
		for step: int in range(2):
			if chain[step] == chain[2]:
				return "A finisher must not be reachable as an opening step"

	for attack: AttackData in [
		player.punch_cross_attack_data,
		player.uppercut_attack_data,
		player.turn_kick_attack_data,
	]:
		var pose_count := frames.get_frame_count(attack.animation_name)
		if attack.animation_frame_starts.size() != pose_count:
			return "%s schedules %d poses for %d textures" % [
				attack.attack_name,
				attack.animation_frame_starts.size(),
				pose_count,
			]
		if attack.animation_frame_starts[0] != 0:
			return "%s must begin at attack frame zero" % attack.attack_name
		var previous_start: int = -1
		for pose_index: int in range(pose_count):
			var pose_start := attack.animation_frame_starts[pose_index]
			if pose_start <= previous_start or pose_start >= attack.total_frames():
				return "%s has an invalid pose start at index %d" % [
					attack.attack_name,
					pose_index,
				]
			previous_start = pose_start
	return ""


## A landed hit knocks its target back, so a chain whose later steps stood
## still could never reach the enemy its own opener pushed away. Each step
## after the opener closes that distance itself.
func _test_the_chain_reaches_a_knocked_back_target(player: Player, target: Node2D) -> String:
	await _reset(player, target)
	# The standing dummy would absorb the very hits this slice is about, so
	# every landed hit here is read from the Williams that takes the knockback.
	await _move_target(target, player.global_position.x + OUT_OF_REACH_X)
	for use_kick: bool in [false, true]:
		var chain: Array[AttackData] = player.kick_chain if use_kick else player.punch_chain
		var williams := await _spawn_sparring_williams(player)
		var reaction := williams.get(&"hit_reaction_component") as HitReactionComponent
		var health := williams.get(&"health_component") as HealthComponent
		var error := ""
		for step: int in range(3):
			var health_before := health.current_health
			var step_error := await _run_one_attack(player, use_kick)
			if not step_error.is_empty():
				error = "Knockback chain step %d: %s" % [step + 1, step_error]
				break
			if _last_attack != chain[step]:
				error = "Knockback chain step %d used %s" % [
					step + 1,
					_last_attack.attack_name,
				]
				break
			if health.current_health >= health_before:
				error = "%s could not reach a target its own chain knocked back" % [
					_last_attack.attack_name,
				]
				break
			# Press again only once the target has stopped sliding away, which
			# is the furthest the next step can ever be asked to reach. The
			# wait is capped by the chain's own window, so a combo pressed this
			# patiently still cannot lapse.
			var patience: int = (
				player.attack_chain_component.open_frames
				- player.input_component.chord_window_frames
				- 1
			)
			for _frame: int in range(patience):
				if not reaction.is_incapacitated():
					break
				player._physics_process(DELTA)
				await physics_frame
		if error.is_empty() and reaction.current_reaction != HitReactionComponent.KNOCKDOWN:
			error = "The finisher must leave the target knocked down, got %s" % [
				reaction.current_reaction,
			]
		williams.queue_free()
		await physics_frame
		if not error.is_empty():
			return error
	await _move_target(target, player.global_position.x)
	return ""


## A Williams who stands still, takes the knockback, and survives a whole
## chain so the slice measures reach rather than health.
func _spawn_sparring_williams(player: Player) -> Node2D:
	var williams := WILLIAMS_SCENE.instantiate() as Node2D
	williams.set(&"acquire_player_target", false)
	var stats := (williams.get(&"fighter_stats") as FighterStats).duplicate(true) as FighterStats
	stats.max_health = 500
	williams.set(&"fighter_stats", stats)
	root.add_child(williams)
	await physics_frame
	williams.global_position = Vector2(
		player.global_position.x + SPARRING_OFFSET_X,
		player.global_position.y
	)
	await physics_frame
	return williams


## Each finisher knocks down on its own account, not merely as the third hit
## a target takes: a fresh Williams goes down to one uppercut or one turning
## kick.
func _test_each_finisher_knocks_down(player: Player) -> String:
	var williams := WILLIAMS_SCENE.instantiate() as Node2D
	williams.set(&"acquire_player_target", false)
	root.add_child(williams)
	await physics_frame
	williams.set_physics_process(false)
	williams.global_position = Vector2(
		player.global_position.x + WILLIAMS_OFFSET_X,
		player.global_position.y
	)
	await physics_frame

	var reaction := williams.get(&"hit_reaction_component") as HitReactionComponent
	var health := williams.get(&"health_component") as HealthComponent
	var error := ""
	for finisher: AttackData in [
		player.uppercut_attack_data,
		player.turn_kick_attack_data,
	]:
		reaction.reset()
		health.configure(williams.get(&"fighter_stats") as FighterStats)
		player.combat_component.cancel_attack()
		player.combat_component.set_facing(1.0)
		if not player.combat_component.try_start_attack(finisher):
			error = "Setup: %s did not start" % finisher.attack_name
			break
		while player.combat_component.is_attacking:
			player._physics_process(DELTA)
			await physics_frame
		if health.current_health >= (williams.get(&"fighter_stats") as FighterStats).max_health:
			error = "%s did not reach Williams" % finisher.attack_name
			break
		if reaction.current_reaction != HitReactionComponent.KNOCKDOWN:
			error = "%s left Williams in %s instead of a knockdown" % [
				finisher.attack_name,
				reaction.current_reaction,
			]
			break
	williams.queue_free()
	return error


## Presses attack (or kick) and runs whatever it starts to completion,
## recording the attack, the animation it presented, and whether it connected.
func _run_one_attack(player: Player, use_kick: bool = false) -> String:
	_last_attack = null
	_last_attack_animation = &""
	_last_attack_landed = false
	if use_kick:
		player.input_component.queue_kick()
	else:
		player.input_component.queue_attack()
	var landed: Array[bool] = [false]
	var connection := func(
		_hurtbox: HurtboxComponent,
		_attack: AttackData,
		_knockback: Vector2
	) -> void:
		landed[0] = true
	player.combat_component.hit_landed.connect(connection)
	for _frame: int in range(12):
		player._physics_process(DELTA)
		await physics_frame
		if player.combat_component.is_attacking:
			break
	if not player.combat_component.is_attacking:
		player.combat_component.hit_landed.disconnect(connection)
		return "A queued press did not start an attack"
	_last_attack = player.combat_component.current_attack_data
	_last_attack_animation = player.visuals.animated_sprite.animation
	while player.combat_component.is_attacking:
		player._physics_process(DELTA)
		await physics_frame
	player.combat_component.hit_landed.disconnect(connection)
	_last_attack_landed = landed[0]
	return ""


func _make_target(at_position: Vector2) -> Node2D:
	var target := Node2D.new()
	target.global_position = at_position
	var health := HealthComponent.new()
	health.name = "Health"
	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Hurtbox"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = TARGET_HURTBOX_SIZE
	collision.shape = shape
	collision.position = TARGET_HURTBOX_OFFSET
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.add_child(collision)
	hurtbox.health_component = health
	target.add_child(health)
	target.add_child(hurtbox)
	health.configure(FighterStats.new())
	return target


func _move_target(target: Node2D, to_x: float) -> void:
	target.global_position.x = to_x
	# The hurtbox is an Area2D: its new transform reaches the physics server on
	# the next flush, and the hitbox queries that server directly.
	await physics_frame


func _reset(player: Player, target: Node2D) -> void:
	player.combat_component.cancel_attack()
	player.jump_component.land_immediately()
	player.input_component.clear_buffered_actions()
	player.combat_component.set_facing(1.0)
	player.visuals.set_facing(1.0)
	player.state_machine.transition_to(PlayerStateMachine.IDLE)
	player.attack_chain_component.reset()
	player.hit_reaction_component.reset()
	player.health_component.configure(player.fighter_stats)
	var health := target.get_node("Health") as HealthComponent
	health.configure(FighterStats.new())
	(target.get_node("Hurtbox") as HurtboxComponent).is_invulnerable = false
	await _move_target(target, player.global_position.x)


func _fail(message: String) -> void:
	push_error("COMBO_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
