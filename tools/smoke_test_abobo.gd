extends SceneTree

const PLAYER := preload("res://features/actors/player/player.tscn")
const ABOBO := preload("res://features/actors/enemies/abobo/abobo.tscn")
const WILLIAMS := preload("res://features/actors/enemies/williams/williams.tscn")
const ALLEY := preload("res://levels/prototype_alley/prototype_alley.tscn")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []
var player: Player
var enemy: Abobo
var sounds: Array[Node] = []
var impacts: Array[Node] = []
var landing_frames: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _spawn(direction: float = 1.0) -> void:
	sounds.clear()
	impacts.clear()
	landing_frames.clear()
	player = PLAYER.instantiate() as Player
	enemy = ABOBO.instantiate() as Abobo
	enemy.position = Vector2(250, 180)
	player.position = enemy.position + Vector2(28 * direction, 0)
	enemy.acquire_player_target = false
	root.add_child(player)
	root.add_child(enemy)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.audio_component.playback_requested.connect(_on_player_sound)
	enemy.audio_component.playback_requested.connect(_on_enemy_sound)
	player.hit_reaction_component.ground_landed.connect(_on_landing)
	await physics_frame


func _on_player_sound(sound: AudioStreamPlayer2D) -> void:
	sounds.append(sound)


func _on_enemy_sound(sound: AudioStreamPlayer2D) -> void:
	impacts.append(sound)


func _on_landing() -> void:
	landing_frames.append(enemy.throw_component.frame if is_instance_valid(enemy) else -1)


func _tick(count: int = 1) -> void:
	for index: int in range(count):
		if is_instance_valid(player) and player.is_inside_tree():
			player._physics_process(1.0 / 60.0)
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			enemy._physics_process(1.0 / 60.0)
		await physics_frame


func _interrupt_acquisition(_previous: StringName, current: StringName) -> void:
	if current == EnemyStateMachine.THROW:
		enemy.health_component.take_damage(1000)


func _cleanup() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await physics_frame
	await physics_frame


func _run() -> void:
	await _spawn()
	var frames := enemy.visuals.animated_sprite.sprite_frames
	for name: StringName in [&"idle", &"walk", &"walk_up", &"punch", &"hurt", &"knockdown", &"death", &"throw"]:
		_check(frames.has_animation(name) and frames.get_frame_count(name) > 0, "Abobo clip: %s" % name)
		for index: int in range(frames.get_frame_count(name)):
			_check(frames.get_frame_texture(name, index).get_size() == Vector2(96, 96), "Abobo canvas")
	_check(frames.get_frame_count(&"throw") == 4 and not frames.get_animation_loop(&"throw"), "Four scheduled throw poses")
	_check(player.visuals.animated_sprite.sprite_frames.get_frame_count(&"being_thrown") == 3, "Billy's three reference victim poses")
	_check(enemy.visuals.position == Vector2(0, -48), "Abobo feet baseline")
	_check(not enemy.can_be_hair_grabbed(), "Heavyweight cannot enter Williams hair-grab")
	# Runtime stats/HP are not shared between enemy instances.
	var other := ABOBO.instantiate() as Abobo
	other.acquire_player_target = false
	root.add_child(other)
	other.set_physics_process(false)
	enemy.health_component.take_damage(10)
	_check(other.health_component.current_health == 140, "Independent health")
	other.queue_free()
	await _cleanup()

	# Both directions, one clock, exact poses, single damage/landing/audio,
	# no jump/chord/hair-grab competition, recovery without a second fall.
	for direction: float in [1.0, -1.0]:
		await _spawn(direction)
		var move := enemy.throw_component
		_check(move.try_start(player), "Close-range acquisition both directions")
		var voice := enemy.audio_component.action_voice_player
		_check(voice != null and voice.bus == &"Voice" and voice.stream.resource_path == "res://assets/audio/voice/voice_05_abobo_throws.wav", "Abobo throw voice resource and bus")
		_check(impacts == [voice], "One voice at confirmed paired start")
		_check(not move.try_start(player) and impacts == [voice], "Repeated active attempt stays silent")
		_check(player.throw_owner == move and not player.can_hair_grab(), "Exclusive victim owner")
		_check(player.state_machine.current_state == PlayerStateMachine.THROWN, "Explicit victim state")
		var initial_x := player.position.x
		player.input_component.queue_jump()
		player.input_component.queue_attack()
		player.input_component.queue_kick()
		Input.action_press(&"move_left")
		await _tick(16)
		_check(move.frame == 16 and not player.jump_component.is_airborne, "Exactly one clock and no ordinary jump")
		_check(not player.combat_component.is_attacking and not player.hair_grab_component.is_active(), "No competing moves")
		_check(enemy.visuals.animated_sprite.frame == 2 and player.visuals.animated_sprite.frame == 0, "Lift uses reference poses")
		_check(player.visuals.position.y < -40, "Carry height visible")
		await _tick(16)
		_check(enemy.visuals.animated_sprite.frame == 3 and player.visuals.animated_sprite.frame == 1, "Release/tumble poses")
		_check(enemy.visuals.animated_sprite.flip_h == (direction < 0), "Mirrored throw facing")
		_check(player.health_component.current_health == 100 and sounds.is_empty(), "No early damage or landing")
		await _tick(15)
		_check(move.frame == 47 and player.visuals.position.y < -40, "Airborne until landing")
		await _tick()
		_check(move.has_landed() and player.visuals.animated_sprite.frame == 2, "Prone at landing")
		_check(landing_frames == [48] and sounds == [player.audio_component.ground_fall_player], "Exactly one landing SFX at frame 48")
		_check(impacts == [voice, enemy.audio_component.punch_hit_player], "One start voice and one confirmed throw impact SFX")
		_check(player.health_component.current_health == 76, "Throw damage once at landing")
		_check(player.visuals.position == Vector2(0, -40), "Landing restores baseline")
		Input.action_release(&"move_left")
		await _tick(8)
		_check(not move.is_active() and player.throw_owner == null, "Both owners released on completion")
		_check((player.position.x - initial_x) * direction < -119, "Over-shoulder travel behind Abobo")
		_check(player.hit_reaction_component.current_reaction == HitReactionComponent.KNOCKDOWN, "Prone/get-up handoff")
		_check(player.hit_reaction_component.reaction_frame == 16, "No replayed fall")
		_check(player.get_collision_exceptions().is_empty() and enemy.get_collision_exceptions().is_empty(), "Collision exception cleanup")
		await _tick(65)
		_check(not player.hit_reaction_component.is_incapacitated(), "Billy recovers")
		_check(impacts.count(voice) == 1, "No repeated voice during flight, landing or recovery")
		player.position = enemy.position + Vector2(28 * direction, 0)
		_check(move.try_start(player) and impacts.count(voice) == 2, "Next actual throw gets its own voice")
		move.release()
		_check(landing_frames == [48] and player.health_component.current_health == 76, "No duplicated landing/damage after recovery")
		_check(not player.combat_component.is_attacking and not player.jump_component.is_airborne, "Inputs do not leak out of throw")
		await _cleanup()

	# AI (not direct activation) approaches and selects a throw, respects
	# reaction delay and cooldown, and punches when Billy cannot be grabbed.
	await _spawn()
	player.position.x += 70
	enemy.set_target(player)
	await _tick(29)
	_check(not enemy.throw_component.is_active(), "Spawn reaction delay")
	for index: int in range(150):
		await _tick()
		if enemy.throw_component.is_active():
			break
	_check(enemy.throw_component.is_active(), "Live AI approaches and throws")
	enemy.throw_component.release()
	await _tick(10)
	_check(not enemy.throw_component.is_active(), "Throw cooldown prevents immediate regrab")
	await _cleanup()

	await _spawn()
	enemy.set_target(player)
	player.jump_component.try_jump()
	_check(not enemy.throw_component.try_start(player), "Airborne player excluded")
	player.jump_component.land_immediately()
	player.combat_component.try_start_attack()
	_check(not enemy.throw_component.try_start(player), "Attacking player excluded")
	for index: int in range(32):
		enemy._physics_process(1.0 / 60.0)
	_check(enemy.combat_component.is_attacking, "AI fallback punch against ungrabbable player")
	player.combat_component.cancel_attack()
	enemy.combat_component.cancel_attack()
	player.position.y += 15
	_check(not enemy.throw_component.try_start(player), "Cross-lane acquisition excluded")
	player.position.y -= 15
	player.hurtbox.is_invulnerable = true
	_check(not enemy.throw_component.try_start(player), "Invulnerable player excluded")
	player.hurtbox.is_invulnerable = false
	player.climb_component.is_on_platform = true
	_check(not enemy.throw_component.try_start(player), "Elevated player excluded")
	player.climb_component.is_on_platform = false
	_check(not impacts.has(enemy.audio_component.action_voice_player), "Rejected attempts and fallback punch have no throw voice")
	await _cleanup()

	# Competing owners, queued despawn and synchronous acquisition callbacks.
	await _spawn()
	var rival := ABOBO.instantiate() as Abobo
	rival.acquire_player_target = false
	rival.position = enemy.position
	root.add_child(rival)
	rival.set_physics_process(false)
	_check(enemy.throw_component.try_start(player), "First owner claims")
	_check(not rival.throw_component.try_start(player), "Second owner cannot steal")
	rival.queue_free()
	enemy.throw_component.release()
	player.queue_free()
	_check(not enemy.throw_component.try_start(player), "Queued victim cannot be acquired")
	await _cleanup()

	await _spawn()
	enemy.state_machine.state_changed.connect(_interrupt_acquisition)
	_check(not enemy.throw_component.try_start(player), "Synchronous death interrupts acquisition")
	_check(not impacts.has(enemy.audio_component.action_voice_player), "Interrupted acquisition has no throw voice")
	_check(player.throw_owner == null and player.get_collision_exceptions().is_empty(), "No stale claim after acquisition callback")
	await _cleanup()

	# World walls clip travel without preventing the landing/release.
	for direction: float in [1.0, -1.0]:
		await _spawn(direction)
		var wall := StaticBody2D.new()
		wall.position = enemy.position - Vector2(direction * 60, 0)
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(8, 160)
		collider.shape = rectangle
		wall.add_child(collider)
		root.add_child(wall)
		await physics_frame
		_check(enemy.throw_component.try_start(player), "Wall flight setup")
		await _tick(56)
		_check((player.position.x - wall.position.x) * direction >= 10.9, "Throw respects solid walls")
		_check(player.throw_owner == null and landing_frames == [48], "Clipped arc still lands/releases once")
		wall.queue_free()
		await _cleanup()

	# Lethal landing shows full flight, then death/prone exactly once.
	await _spawn()
	player.health_component.take_damage(99)
	_check(enemy.throw_component.try_start(player), "Lethal setup")
	await _tick(47)
	_check(not player.is_dead(), "Lethal throw does not skip flight")
	await _tick()
	_check(player.is_dead() and player.throw_owner == null and not enemy.throw_component.is_active(), "Lethal landing clears pair")
	_check(player.hit_reaction_component.reaction_frame == 16, "Lethal landing skips second death fall")
	await _tick(30)
	_check(landing_frames == [48] and sounds.count(player.audio_component.death_voice_player) == 1, "Single lethal landing and death voice")
	await _cleanup()

	# The same cleanup path must be safe from either side and at every phase.
	for at_frame: int in [8, 32, 50]:
		for kind: String in ["enemy_hit", "player_hit", "enemy_death", "player_death", "enemy_remove", "player_remove", "enemy_free", "player_free", "enemy_reaction", "player_reaction", "manual"]:
			await _spawn()
			var move := enemy.throw_component
			_check(move.try_start(player), "Lifecycle setup")
			await _tick(at_frame)
			match kind:
				"enemy_hit": enemy.hurtbox.receive_attack(player.combat_component.attack_data, Vector2.ZERO, player)
				"player_hit": player.hurtbox.receive_attack(enemy.combat_component.attack_data, Vector2.ZERO, enemy)
				"enemy_death": enemy.health_component.take_damage(1000)
				"player_death": player.health_component.take_damage(1000)
				"enemy_remove": root.remove_child(enemy)
				"player_remove": root.remove_child(player)
				"enemy_free": enemy.queue_free()
				"player_free": player.queue_free()
				"enemy_reaction": enemy.hit_reaction_component.begin_death()
				"player_reaction": player.hit_reaction_component.begin_death()
				"manual":
					move.release()
					move.release()
			await physics_frame
			await physics_frame
			if is_instance_valid(player):
				_check(player.throw_owner == null, "Victim cleanup %s/%d" % [kind, at_frame])
				_check(player.visuals.position == Vector2(0, -40), "Baseline cleanup %s/%d" % [kind, at_frame])
				_check(player.get_collision_exceptions().is_empty(), "Victim collisions cleanup")
			if is_instance_valid(enemy):
				_check(not move.is_active() and move.victim == null, "Thrower cleanup %s/%d" % [kind, at_frame])
				_check(enemy.get_collision_exceptions().is_empty(), "Thrower collisions cleanup")
			if at_frame >= 24:
				_check(landing_frames.size() == 1, "Flight/prone interruption lands once: %s/%d" % [kind, at_frame])
			await _cleanup()

	# Boss scene is playable through the existing encounter contract.
	var alley := ALLEY.instantiate() as PrototypeAlley
	root.add_child(alley)
	await physics_frame
	var encounters := alley.encounter_controllers()
	_check(encounters.size() == 4, "Four sequential encounters")
	for encounter: EncounterController in encounters.slice(0, 3):
		_check(encounter.enemy_scene == WILLIAMS and encounter.enemy_count == 3, "Earlier three Williams waves preserved")
		encounter.enabled = false
	_check(encounters[3].enemy_scene == ABOBO and encounters[3].enemy_count == 1, "One boss Abobo")
	alley.player.set_physics_process(false)
	alley.player.position = Vector2(encounters[3].lock_x, 188)
	await physics_frame
	await physics_frame
	var boss: Abobo
	for actor: Node in alley.actors.get_children():
		if actor is Abobo:
			boss = actor
	_check(boss != null and encounters[3].alive_count == 1 and alley.camera.is_locked, "Boss spawns and locks")
	if boss != null:
		_check(boss.target == alley.player, "Spawned Abobo targets Billy")
		boss.health_component.take_damage(1000)
		for index: int in range(100):
			await physics_frame
	_check(encounters[3].is_cleared() and not alley.camera.is_locked, "Abobo death clears/unlocks once")
	_check(alley.state == PrototypeAlley.PLAYING and alley.music.playing, "Boss death alone does not clear stage or stop BGM")
	alley.player.position.x = alley.exit.position.x
	await physics_frame
	await physics_frame
	_check(alley.state == PrototypeAlley.CLEARED and not alley.music.playing and alley.stage_clear_music.playing, "Boss death then exit replaces BGM with stage clear")
	await AudioSettle.free_level(self, alley)

	if failures.is_empty():
		print("ABOBO_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("ABOBO_SMOKE_TEST_FAIL: " + message)
		quit(1)
