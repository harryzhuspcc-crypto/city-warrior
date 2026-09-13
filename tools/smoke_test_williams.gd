extends SceneTree

const WILLIAMS_SCENE_PATH: String = "res://features/actors/enemies/williams/williams.tscn"
const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(WILLIAMS_SCENE_PATH):
		_fail("Williams scene is missing at %s" % WILLIAMS_SCENE_PATH)
		return
	var scene := load(WILLIAMS_SCENE_PATH) as PackedScene
	var enemy := scene.instantiate() as CharacterBody2D
	if enemy == null:
		_fail("Williams must be a CharacterBody2D")
		return
	var script := enemy.get_script() as Script
	if script == null or script.get_global_name() != &"Williams":
		_fail("Williams root must use the Williams orchestrator class")
		return

	root.add_child(enemy)
	await physics_frame

	var error: String = await _test_standalone_scene(enemy)
	if not error.is_empty():
		_fail(error)
		return
	enemy.queue_free()
	await physics_frame

	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await physics_frame

	for slice: Callable in [
		_test_approach_and_attack,
		_test_billy_hit_reactions,
		_test_retreat_after_attack,
		_test_depth_alignment,
		_test_airborne_knockdown,
		_test_death_without_hit,
		_test_depth_alignment_from_overlap,
		_test_lazy_target_and_dead_target,
		_test_chain_reset_zero,
		_test_interrupted_attack_states,
		_test_recovery_tick_locomotion,
		_test_retreat_ends_at_wall,
		_test_hit_chain_decays,
	]:
		await _reset_player(player, Vector2(100.0, 150.0))
		error = await slice.call(player, scene)
		if not error.is_empty():
			_fail(error)
			return

	print("WILLIAMS_SMOKE_TEST_PASS")
	quit()


## A null target spawns a passive enemy: it still reacts to hits but never
## acquires Billy through the player group.
func _spawn_enemy(
	scene: PackedScene,
	position: Vector2,
	target: Node2D,
	reaction_delay_frames: int = -1
) -> Williams:
	var enemy := scene.instantiate() as Williams
	enemy.global_position = position
	enemy.target = target
	enemy.acquire_player_target = target != null
	enemy.ai_component.retreat_probability = 0.0
	if reaction_delay_frames >= 0:
		enemy.ai_component.reaction_delay_frames = reaction_delay_frames
	root.add_child(enemy)
	await physics_frame
	return enemy


func _reset_player(player: Player, position: Vector2) -> void:
	player.combat_component.cancel_attack()
	player.input_component.clear_buffered_actions()
	player.jump_component.land_immediately()
	player.hit_reaction_component.reset()
	player.health_component.restore_full_health()
	player.state_machine.transition_to(PlayerStateMachine.IDLE)
	player.global_position = position
	player.combat_component.set_facing(1.0)
	await physics_frame


## Knockback pushes Williams out of punch reach, so each follow-up punch
## starts from a fresh in-range position.
func _step_into_punch_range(player: Player, enemy: Williams) -> void:
	player.global_position = enemy.global_position + Vector2(-26.0, 0.0)
	await physics_frame


func _wait_until(condition: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


## Williams starts to the right of Billy, walks left into punch range, and
## his punch physically reaches Billy's hurtbox: damage, hitstun, knockback
## away from Williams, then recovery to IDLE.
func _test_approach_and_attack(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(120.0, 0.0), player)
	var start_x := enemy.global_position.x
	var delay := enemy.ai_component.reaction_delay_frames
	for _frame: int in range(delay - 2):
		await physics_frame
	if enemy.state_machine.current_state != EnemyStateMachine.IDLE:
		return "Williams must wait through its reaction delay before approaching"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.APPROACH,
		12
	):
		return "Williams did not enter APPROACH after its reaction delay"
	for _frame: int in range(6):
		await physics_frame
	if enemy.global_position.x >= start_x:
		return "Approaching Williams did not move toward Billy"
	if enemy.ai_component.facing >= 0.0 or not enemy.visuals.animated_sprite.flip_h:
		return "Williams must face Billy while approaching"
	if enemy.visuals.animated_sprite.animation != &"walk":
		return "Approaching Williams must play the walk animation"

	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		240
	):
		return "Williams never attacked after reaching range"
	var horizontal_gap := absf(enemy.global_position.x - player.global_position.x)
	if horizontal_gap > enemy.ai_component.attack_range_x + 1.0:
		return "Williams attacked from %.1f px, beyond its %.1f px range" % [
			horizontal_gap,
			enemy.ai_component.attack_range_x,
		]
	if enemy.combat_component.current_attack_data.attack_name != &"williams_punch":
		return "Williams must attack with williams_punch.tres"
	if enemy.visuals.animated_sprite.animation != &"punch":
		return "Williams attack must present the punch animation"
	if enemy.visuals.animated_sprite.frame != 0:
		return "Williams punch startup must hold the wind-up pose"

	var player_x_before_hit := player.global_position.x
	var punch := enemy.combat_component.attack_data
	if not await _wait_until(
		func() -> bool: return player.state_machine.current_state == PlayerStateMachine.HITSTUN,
		punch.startup_frames + punch.active_frames + 2
	):
		return "Williams punch did not put Billy into HITSTUN"
	if player.health_component.current_health != player.fighter_stats.max_health - punch.damage:
		return "Billy took %d damage instead of %d" % [
			player.fighter_stats.max_health - player.health_component.current_health,
			punch.damage,
		]
	if player.visuals.animated_sprite.animation != &"hurt":
		return "Billy in HITSTUN must present the hurt animation"
	for _frame: int in range(4):
		await physics_frame
	if player.global_position.x >= player_x_before_hit:
		return "Billy must be knocked back away from Williams"
	if not await _wait_until(
		func() -> bool: return player.state_machine.current_state == PlayerStateMachine.IDLE,
		punch.hitstun_frames + 2
	):
		return "Billy did not recover to IDLE after hitstun"
	if player.health_component.current_health != player.fighter_stats.max_health - punch.damage:
		return "Williams punch must damage Billy exactly once"

	# The cooldown counts from the end of the punch: no second attack until it
	# expires, then an immediate follow-up because Billy is still in range.
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state != EnemyStateMachine.ATTACK,
		punch.total_frames() + 2
	):
		return "Williams punch did not finish"
	for _frame: int in range(enemy.ai_component.attack_cooldown_frames - 2):
		if enemy.state_machine.current_state == EnemyStateMachine.ATTACK:
			return "Williams attacked again before its cooldown expired"
		await physics_frame
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		14
	):
		return "Williams did not attack again once its cooldown expired"

	enemy.queue_free()
	await physics_frame
	return ""


## Billy's punch reaches a passive Williams: hitstun with knockback, a third
## consecutive hit knocks him down and makes him invulnerable, and a lethal
## hit leaves him dead, non-blocking, and eventually removed.
func _test_billy_hit_reactions(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(26.0, 0.0), null)
	enemy.death_linger_frames = 12
	if enemy.ai_component.has_target():
		return "A passive Williams must not acquire Billy through the player group"
	var punch := player.combat_component.attack_data
	var expected_health := enemy.fighter_stats.max_health

	for hit_index: int in range(2):
		await _step_into_punch_range(player, enemy)
		var enemy_x_before_hit := enemy.global_position.x
		_punch_without_chaining(player)
		if not await _wait_until(
			func() -> bool: return enemy.state_machine.current_state == (EnemyStateMachine.STATUS1 if hit_index == 0 else EnemyStateMachine.STATUS2),
			player.input_component.chord_window_frames + punch.startup_frames + punch.active_frames + 2
		):
			return "Billy punch %d did not put Williams into HITSTUN" % (hit_index + 1)
		expected_health -= punch.damage
		if enemy.health_component.current_health != expected_health:
			return "Williams health is %d after hit %d instead of %d" % [
				enemy.health_component.current_health,
				hit_index + 1,
				expected_health,
			]
		var expected_pose: StringName = &"status1" if hit_index == 0 else &"status2"
		if enemy.visuals.animated_sprite.animation != expected_pose:
			return "Williams must present its active staged hit pose"
		for _frame: int in range(4):
			await physics_frame
		if enemy.global_position.x <= enemy_x_before_hit:
			return "Williams must be knocked back away from Billy"
		if not await _wait_until(
			func() -> bool: return not player.combat_component.is_attacking,
			punch.total_frames()
		):
			return "Billy punch %d did not finish" % (hit_index + 1)

	await _step_into_punch_range(player, enemy)
	_punch_without_chaining(player)
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.KNOCKDOWN,
		player.input_component.chord_window_frames + punch.startup_frames + punch.active_frames + 2
	):
		return "Third consecutive hit must knock Williams down"
	expected_health -= punch.damage
	if not enemy.hurtbox.is_invulnerable:
		return "Knocked-down Williams must be invulnerable"
	if enemy.visuals.animated_sprite.animation != &"knockdown":
		return "Williams in KNOCKDOWN must present the knockdown animation"
	if not await _wait_until(
		func() -> bool: return not player.combat_component.is_attacking,
		punch.total_frames()
	):
		return "Knockdown punch did not finish"
	await _step_into_punch_range(player, enemy)
	_punch_without_chaining(player)
	for _frame: int in range(
		player.input_component.chord_window_frames + punch.startup_frames + punch.active_frames + 2
	):
		await physics_frame
	if enemy.health_component.current_health != expected_health:
		return "A punch must not damage a knocked-down Williams"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.IDLE,
		enemy.fighter_stats.knockdown_frames + 2
	):
		return "Williams did not get up after its knockdown"
	if enemy.hurtbox.is_invulnerable:
		return "Recovered Williams must be vulnerable again"
	if not await _wait_until(
		func() -> bool: return not player.combat_component.is_attacking,
		punch.total_frames()
	):
		return "Invulnerability punch did not finish"

	var defeats: Array[int] = [0]
	enemy.defeated.connect(func() -> void: defeats[0] += 1)
	var enemy_id := enemy.get_instance_id()
	enemy.health_component.take_damage(enemy.health_component.current_health - 1)
	await _step_into_punch_range(player, enemy)
	_punch_without_chaining(player)
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.DEAD,
		player.input_component.chord_window_frames + punch.startup_frames + punch.active_frames + 2
	):
		return "Lethal punch did not leave Williams DEAD"
	if not enemy.health_component.is_dead():
		return "DEAD Williams must report zero health"
	if enemy.visuals.animated_sprite.animation != &"death":
		return "Dead Williams must present the death animation"
	await physics_frame
	if enemy.collision_layer != 0:
		return "Dead Williams must stop blocking other actors"
	var linger_frames := enemy.death_linger_frames
	if not await _wait_until(
		func() -> bool: return defeats[0] == 1 and instance_from_id(enemy_id) == null,
		linger_frames + 4
	):
		return "Dead Williams must emit defeated and free itself after lingering"
	return ""


## With retreat forced on, a completed punch is followed by walking away.
func _test_retreat_after_attack(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(24.0, 0.0), player, 0)
	enemy.ai_component.retreat_probability = 1.0
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		enemy.ai_component.reaction_delay_frames + 30
	):
		return "In-range Williams did not attack"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.RETREAT,
		enemy.combat_component.attack_data.total_frames() + 4
	):
		return "Williams did not retreat after completing its punch"
	var retreat_start_x := enemy.global_position.x
	for _frame: int in range(6):
		await physics_frame
	if enemy.global_position.x <= retreat_start_x:
		return "Retreating Williams must walk away from Billy"
	if enemy.ai_component.facing >= 0.0:
		return "Retreating Williams must keep facing Billy"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state != EnemyStateMachine.RETREAT,
		enemy.ai_component.retreat_frames + 2
	):
		return "Williams retreat must end after its retreat window"
	enemy.queue_free()
	await physics_frame
	return ""


## Williams offset in depth closes the lane gap before attacking.
func _test_depth_alignment(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(60.0, 30.0), player, 0)
	if not await _wait_until(
		func() -> bool: return enemy.ai_component.movement_direction.y < 0.0,
		12
	):
		return "Williams below Billy must steer upward toward Billy's lane"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		180
	):
		return "Williams never attacked after aligning depth"
	var depth_gap := absf(enemy.global_position.y - player.global_position.y)
	if depth_gap > enemy.ai_component.depth_tolerance + 1.0:
		return "Williams attacked with a %.1f px depth gap" % depth_gap
	enemy.queue_free()
	await physics_frame
	return ""


## A hit that lands while Billy is airborne floors him immediately.
func _test_airborne_knockdown(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(24.0, 0.0), null)
	enemy.set_physics_process(false)
	enemy.combat_component.set_facing(-1.0)
	player.input_component.queue_jump()
	if not await _wait_until(
		func() -> bool: return player.jump_component.is_airborne,
		player.input_component.chord_window_frames + 3
	):
		return "Airborne regression setup did not jump"
	if not enemy.combat_component.try_start_attack():
		return "Airborne regression punch did not start"
	var punch := enemy.combat_component.attack_data
	for _frame: int in range(punch.startup_frames + punch.active_frames):
		enemy.combat_component.physics_tick()
		await physics_frame
	if player.state_machine.current_state != PlayerStateMachine.KNOCKDOWN:
		return "A hit on airborne Billy must knock him down"
	if player.jump_component.is_airborne:
		return "Knocked-down Billy must land immediately"
	if not player.hurtbox.is_invulnerable:
		return "Knocked-down Billy must be invulnerable"
	if not await _wait_until(
		func() -> bool: return player.state_machine.current_state == PlayerStateMachine.IDLE,
		player.fighter_stats.knockdown_frames + 2
	):
		return "Billy did not get up after knockdown"
	enemy.queue_free()
	await physics_frame
	return ""


func _test_standalone_scene(enemy: CharacterBody2D) -> String:
	for property_name: StringName in [
		&"fighter_stats",
		&"health_component",
		&"movement_component",
		&"combat_component",
		&"hurtbox",
		&"hit_reaction_component",
		&"ai_component",
		&"state_machine",
		&"visuals",
	]:
		if enemy.get(property_name) == null:
			return "Williams is missing its %s export" % property_name

	var stats := enemy.get(&"fighter_stats") as FighterStats
	var health := enemy.get(&"health_component") as HealthComponent
	if health.current_health != stats.max_health:
		return "Williams HealthComponent did not initialize from FighterStats"

	var visuals := enemy.get(&"visuals") as Node2D
	var animated_sprite := visuals.get(&"animated_sprite") as AnimatedSprite2D
	if animated_sprite == null:
		return "Williams visuals must expose an AnimatedSprite2D"
	var frames := animated_sprite.sprite_frames
	for animation_contract: Array in [
		[&"idle", 1],
		[&"walk", 4],
		[&"walk_up", 4],
		[&"punch", 3],
		[&"hurt", 2],
		[&"knockdown", 4],
		[&"death", 3],
	]:
		var animation_name := animation_contract[0] as StringName
		var expected_count := animation_contract[1] as int
		if not frames.has_animation(animation_name):
			return "Missing Williams animation: %s" % animation_name
		if frames.get_frame_count(animation_name) != expected_count:
			return "Williams %s must contain %d poses, found %d" % [
				animation_name,
				expected_count,
				frames.get_frame_count(animation_name),
			]
	var pivot_error := _test_feet_pivots(frames)
	if not pivot_error.is_empty():
		return pivot_error

	# Collision contract: enemy body on layer 2, hurtbox on layer 4 scanning
	# player hitboxes (layer 5), hitbox on layer 6 scanning player hurtboxes
	# (layer 3).
	if enemy.collision_layer != 2 or enemy.collision_mask != 3:
		return "Williams body must use actor layer 2 and scan world + actor layers"
	var hurtbox := enemy.get(&"hurtbox") as HurtboxComponent
	if hurtbox.collision_layer != 8 or hurtbox.collision_mask != 16:
		return "Williams hurtbox must sit on layer 4 and scan player hitboxes"
	var combat := enemy.get(&"combat_component") as CombatComponent
	if combat.hitbox.collision_layer != 32 or combat.hitbox.collision_mask != 4:
		return "Williams hitbox must sit on layer 6 and scan player hurtboxes"
	if combat.hitbox.monitoring or not combat.hitbox_shape.disabled:
		return "Williams hitbox must start inactive"

	# F6 safety: without a target the enemy idles in place.
	var state_machine := enemy.get(&"state_machine") as Node
	var start_position := enemy.global_position
	for _frame: int in range(30):
		await physics_frame
	if state_machine.get(&"current_state") != &"idle":
		return "Williams without a target must stay IDLE"
	if not enemy.global_position.is_equal_approx(start_position):
		return "Williams without a target must not move"
	if animated_sprite.animation != &"idle":
		return "Williams without a target must present the idle animation"
	return ""


func _test_feet_pivots(frames: SpriteFrames) -> String:
	# New paired poses use fixed authored body anchors, not a moving feet
	# midpoint (raised knee/rotating victim). Their asset contract is tested
	# in smoke_test_hair_grab.gd.
	for animation_name: StringName in [&"idle", &"walk", &"walk_up", &"punch", &"hurt", &"knockdown", &"death"]:
		for frame_index: int in range(frames.get_frame_count(animation_name)):
			var image := frames.get_frame_texture(animation_name, frame_index).get_image()
			if image.get_width() != 80 or image.get_height() != 80:
				return "Williams %s frame %d is not an 80x80 feet-pivot canvas" % [
					animation_name,
					frame_index,
				]
			for y: int in range(80):
				if image.get_pixel(0, y).a > 0.0 or image.get_pixel(79, y).a > 0.0:
					return "Williams %s frame %d touches a canvas edge" % [
						animation_name,
						frame_index,
					]
			var minimum_x: int = 80
			var maximum_x: int = -1
			for y: int in range(72, 80):
				for x: int in range(80):
					if image.get_pixel(x, y).a > 0.0:
						minimum_x = mini(minimum_x, x)
						maximum_x = maxi(maximum_x, x)
			if maximum_x < minimum_x:
				return "Williams %s frame %d has no floor contact" % [animation_name, frame_index]
			var contact_midpoint := (minimum_x + maximum_x + 1) * 0.5
			if absf(contact_midpoint - 40.0) > 0.5:
				return "Williams %s frame %d feet midpoint is %.1f instead of 40" % [
					animation_name,
					frame_index,
					contact_midpoint,
				]
	return ""


## An isolated hit does not count toward a later knockdown: the consecutive
## hit chain resets FighterStats.hit_chain_reset_frames after recovery, which
## requires the reaction component to tick while nothing is happening.
func _test_hit_chain_decays(player: Player, _scene: PackedScene) -> String:
	var punch := load("res://features/combat/williams_punch.tres") as AttackData
	var reaction := player.hit_reaction_component
	var reset_frames := player.fighter_stats.hit_chain_reset_frames
	if reset_frames <= 0:
		return "This regression needs a positive hit_chain_reset_frames"
	if not player.hurtbox.receive_attack(punch, Vector2(70.0, 0.0), null):
		return "Chain setup: the punch must land on Billy"
	if reaction.consecutive_hits != 1:
		return "A landed hit must start the chain, got %d" % reaction.consecutive_hits
	var recovered := await _wait_until(
		func() -> bool: return not reaction.is_incapacitated(),
		punch.hitstun_frames + 10
	)
	if not recovered:
		return "Chain setup: Billy must recover from the hit"
	if reaction.consecutive_hits != 1:
		return "Recovery alone must not reset the chain"
	var decayed := await _wait_until(
		func() -> bool: return reaction.consecutive_hits == 0,
		reset_frames + 10
	)
	if not decayed:
		return "The chain must reset %d frames after recovery" % reset_frames
	return ""


## Billy's punches chain once they connect, and these slices are about the
## target's own consecutive-hit rules rather than Billy's combo: each press
## here is a fresh opener, exactly as it would be after the chain's window has
## closed.
func _punch_without_chaining(player: Player) -> void:
	player.attack_chain_component.reset()
	player.input_component.queue_attack()


func _fail(message: String) -> void:
	push_error("WILLIAMS_SMOKE_TEST_FAIL: %s" % message)
	quit(1)


## Health reaching zero without a hurtbox hit still plays the fall, lingers,
## and frees the enemy; Billy likewise enters DEAD with the death clip.
func _test_death_without_hit(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(80.0, 0.0), null)
	enemy.death_linger_frames = 8
	var enemy_id := enemy.get_instance_id()
	var defeats: Array[int] = [0]
	enemy.defeated.connect(func() -> void: defeats[0] += 1)
	enemy.health_component.take_damage(enemy.health_component.current_health)
	await physics_frame
	await physics_frame
	if enemy.state_machine.current_state != EnemyStateMachine.DEAD:
		return "Williams killed without a hit must be DEAD"
	if enemy.hit_reaction_component.current_reaction != HitReactionComponent.DEATH:
		return "Williams killed without a hit must run the death reaction"
	if enemy.visuals.animated_sprite.animation != &"death":
		return "Williams killed without a hit must present the death animation"
	if not await _wait_until(
		func() -> bool: return defeats[0] == 1 and instance_from_id(enemy_id) == null,
		12
	):
		return "Williams killed without a hit must still linger, emit defeated, and free"

	player.health_component.take_damage(player.health_component.current_health)
	await physics_frame
	await physics_frame
	if player.state_machine.current_state != PlayerStateMachine.DEAD:
		return "Billy killed without a hit must be DEAD"
	if player.hit_reaction_component.current_reaction != HitReactionComponent.DEATH:
		return "Billy killed without a hit must run the death reaction"
	if player.visuals.animated_sprite.animation != &"death":
		return "Billy killed without a hit must present the death animation"
	return ""


## Williams directly below Billy (bodies overlapping in x) must sidestep,
## align depth, and attack instead of pushing into Billy's body forever.
func _test_depth_alignment_from_overlap(player: Player, scene: PackedScene) -> String:
	for start_dx: float in [0.0, 10.0]:
		var enemy := await _spawn_enemy(
			scene,
			player.global_position + Vector2(start_dx, 30.0),
			player,
			0
		)
		if not await _wait_until(
			func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
			300
		):
			enemy.queue_free()
			return "Williams starting %.0f px beside and 30 px below Billy never attacked" % start_dx
		var depth_gap := absf(enemy.global_position.y - player.global_position.y)
		if depth_gap > enemy.ai_component.depth_tolerance + 1.0:
			enemy.queue_free()
			return "Williams attacked from a %.1f px depth gap after sidestepping" % depth_gap
		var horizontal_gap := absf(enemy.global_position.x - player.global_position.x)
		if horizontal_gap > enemy.ai_component.attack_range_x + 1.0:
			enemy.queue_free()
			return "Williams attacked from %.1f px after sidestepping" % horizontal_gap
		enemy.queue_free()
		await physics_frame
		await _reset_player(player, Vector2(100.0, 150.0))
	return ""


## An enemy that enters the tree before any player still finds Billy later,
## and stops acting once Billy is dead.
func _test_lazy_target_and_dead_target(player: Player, scene: PackedScene) -> String:
	player.remove_from_group(&"player")
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(24.0, 0.0), null, 0)
	enemy.acquire_player_target = true
	for _frame: int in range(10):
		await physics_frame
	if enemy.ai_component.has_target():
		return "Williams must not have a target while no player is grouped"
	player.add_to_group(&"player")
	if not await _wait_until(
		func() -> bool: return enemy.ai_component.has_target(),
		4
	):
		return "Williams must acquire Billy once the player group is populated"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		40
	):
		return "Lazily targeted Williams did not attack"
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state != EnemyStateMachine.ATTACK,
		enemy.combat_component.attack_data.total_frames() + 2
	):
		return "Lazily targeted Williams punch did not finish"

	player.health_component.take_damage(player.health_component.current_health)
	await physics_frame
	var attacks: Array[int] = [0]
	enemy.combat_component.attack_started.connect(func() -> void: attacks[0] += 1)
	for _frame: int in range(150):
		await physics_frame
	if attacks[0] != 0:
		return "Williams attacked a dead Billy %d times" % attacks[0]
	if enemy.state_machine.current_state != EnemyStateMachine.IDLE:
		return "Williams must idle once Billy is dead"
	enemy.queue_free()
	await physics_frame
	return ""


## hit_chain_reset_frames = 0 means the chain resets on recovery, so a third
## hit after a pause is hitstun, not knockdown.
func _test_chain_reset_zero(player: Player, scene: PackedScene) -> String:
	var enemy := scene.instantiate() as Williams
	enemy.global_position = player.global_position + Vector2(26.0, 0.0)
	enemy.acquire_player_target = false
	enemy.fighter_stats = enemy.fighter_stats.duplicate(true) as FighterStats
	enemy.fighter_stats.hit_chain_reset_frames = 0
	root.add_child(enemy)
	await physics_frame
	var punch := player.combat_component.attack_data
	for hit_index: int in range(3):
		await _step_into_punch_range(player, enemy)
		_punch_without_chaining(player)
		if not await _wait_until(
			func() -> bool: return enemy.hit_reaction_component.is_incapacitated(),
			player.input_component.chord_window_frames + punch.startup_frames + punch.active_frames + 2
		):
			return "Chain-reset punch %d did not land" % (hit_index + 1)
		if enemy.state_machine.current_state != EnemyStateMachine.STATUS1:
			return "After recovery, hit %d must be status1, not %s" % [
				hit_index + 1,
				enemy.state_machine.current_state,
			]
		if not await _wait_until(
			func() -> bool: return not enemy.hit_reaction_component.is_incapacitated(),
			enemy.fighter_stats.status1_frames + 2
		):
			return "Chain-reset hit %d did not recover" % (hit_index + 1)
		if enemy.hit_reaction_component.consecutive_hits != 0:
			return "A zero reset window must clear the chain on recovery"
		if not await _wait_until(
			func() -> bool: return not player.combat_component.is_attacking,
			punch.total_frames()
		):
			return "Chain-reset punch %d did not finish" % (hit_index + 1)
	enemy.queue_free()
	await physics_frame
	return ""


## A punch that interrupts Williams' own punch moves him ATTACK → HITSTUN
## with no locomotion state in between.
func _test_interrupted_attack_states(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(26.0, 0.0), player, 0)
	var transitions: Array[StringName] = [enemy.state_machine.current_state]
	enemy.state_machine.state_changed.connect(
		func(_previous: StringName, current: StringName) -> void: transitions.append(current)
	)
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.ATTACK,
		40
	):
		return "Interrupt setup: Williams did not attack"
	_punch_without_chaining(player)
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.STATUS1,
		enemy.combat_component.attack_data.startup_frames
	):
		return "Billy's punch must interrupt Williams during his startup"
	var hitstun_index := transitions.find(EnemyStateMachine.STATUS1)
	if hitstun_index < 1 or transitions[hitstun_index - 1] != EnemyStateMachine.ATTACK:
		return "Interrupted attack must transition ATTACK → HITSTUN directly, got %s" % [transitions]
	enemy.queue_free()
	await physics_frame
	return ""


## On the tick hitstun ends with a direction held, Billy moves that tick
## rather than rendering MOVE while still sliding from knockback.
func _test_recovery_tick_locomotion(player: Player, scene: PackedScene) -> String:
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(24.0, 0.0), null)
	enemy.set_physics_process(false)
	enemy.combat_component.set_facing(-1.0)
	if not enemy.combat_component.try_start_attack():
		return "Recovery-tick setup punch did not start"
	var punch := enemy.combat_component.attack_data
	for _frame: int in range(punch.startup_frames + punch.active_frames):
		enemy.combat_component.physics_tick()
		await physics_frame
	if player.state_machine.current_state != PlayerStateMachine.HITSTUN:
		return "Recovery-tick setup did not put Billy into HITSTUN"
	enemy.combat_component.cancel_attack()
	Input.action_press(&"move_right")
	var recovered := await _wait_until(
		func() -> bool: return player.state_machine.current_state == PlayerStateMachine.MOVE,
		punch.hitstun_frames + 2
	)
	var recovery_velocity := player.velocity
	Input.action_release(&"move_right")
	if not recovered:
		return "Billy holding right did not resume MOVE after hitstun"
	if recovery_velocity.x <= 0.0:
		return "Recovery tick rendered MOVE with velocity %s instead of walking" % recovery_velocity
	enemy.queue_free()
	await physics_frame
	return ""


## A retreat that runs into a wall ends instead of walking in place.
func _test_retreat_ends_at_wall(player: Player, scene: PackedScene) -> String:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(8.0, 120.0)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.global_position = player.global_position + Vector2(48.0, 0.0)
	root.add_child(wall)
	var enemy := await _spawn_enemy(scene, player.global_position + Vector2(24.0, 0.0), player, 0)
	enemy.ai_component.retreat_probability = 1.0
	if not await _wait_until(
		func() -> bool: return enemy.state_machine.current_state == EnemyStateMachine.RETREAT,
		enemy.combat_component.attack_data.total_frames() + 40
	):
		wall.queue_free()
		return "Wall retreat setup: Williams did not retreat"
	var retreat_window := enemy.ai_component.retreat_frames
	var still_retreating := 0
	for _frame: int in range(retreat_window):
		await physics_frame
		if enemy.state_machine.current_state == EnemyStateMachine.RETREAT:
			still_retreating += 1
	wall.queue_free()
	enemy.queue_free()
	await physics_frame
	if still_retreating >= retreat_window - 1:
		return "Williams kept retreating into a wall for the whole retreat window"
	return ""

