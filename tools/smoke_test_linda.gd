extends SceneTree

const LINDA := preload("res://features/actors/enemies/linda/linda.tscn")
const PLAYER := preload("res://features/actors/player/player.tscn")
const WILLIAMS := preload("res://features/actors/enemies/williams/williams.tscn")
const ALLEY := preload("res://levels/prototype_alley/prototype_alley.tscn")
const HIT := preload("res://features/combat/billy_punch.tres")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")

var failures: Array[String] = []
var player: Player
var linda: Linda
var sounds: Array[AudioStreamPlayer2D] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _spawn(distance: float = 43.0, direction: float = 1.0) -> void:
	sounds.clear()
	player = PLAYER.instantiate() as Player
	linda = LINDA.instantiate() as Linda
	linda.position = Vector2(250, 180)
	player.position = linda.position + Vector2(distance * direction, 0)
	linda.acquire_player_target = false
	root.add_child(player)
	root.add_child(linda)
	player.set_physics_process(false)
	linda.set_physics_process(false)
	linda.set_target(player)
	linda.ai_component.facing = direction
	linda.combat_component.set_facing(direction)
	linda.audio_component.playback_requested.connect(_on_sound)
	await physics_frame
	await physics_frame


func _on_sound(sound: AudioStreamPlayer2D) -> void:
	sounds.append(sound)


func _cleanup() -> void:
	player.queue_free()
	linda.queue_free()
	await physics_frame
	await physics_frame


func _run() -> void:
	await _spawn()
	var frames := linda.visuals.animated_sprite.sprite_frames
	var counts := {&"idle": 1, &"walk": 4, &"walk_up": 4, &"punch": 3,
		&"whip": 4, &"hurt": 2, &"status1": 2, &"status2": 1,
		&"knockdown": 4, &"death": 3}
	for clip: StringName in counts:
		_check(frames.has_animation(clip), "Missing Linda animation: %s" % clip)
		_check(frames.get_frame_count(clip) == counts[clip], "Linda pose count: %s" % clip)
		_check(frames.get_animation_loop(clip) == (clip in [&"idle", &"walk", &"walk_up"]), "Only locomotion loops")
		for index: int in range(frames.get_frame_count(clip)):
			var texture := frames.get_frame_texture(clip, index)
			_check(texture is AtlasTexture and texture.get_size() == Vector2(80, 80), "Atlas canvas/pivot")
			var image := texture.get_image()
			_check(not image.is_invisible() and image.get_pixel(0, 0).a == 0.0, "Transparent nonempty frame")
	_check(linda.visuals.position == Vector2(0, -40), "Feet at actor origin")
	_check(not linda.can_be_hair_grabbed(), "Do not use Williams-only captive artwork")
	linda.visuals.sync_locomotion(true, Vector2.UP, -1.0)
	_check(linda.visuals.animated_sprite.animation == &"walk_up" and linda.visuals.animated_sprite.flip_h, "Up-walk and mirror")
	linda.visuals.sync_locomotion(true, Vector2.DOWN, 1.0)
	_check(linda.visuals.animated_sprite.animation == &"walk" and not linda.visuals.animated_sprite.flip_h, "Down-walk and right facing")
	var other := LINDA.instantiate() as Linda
	other.acquire_player_target = false
	root.add_child(other)
	other.set_physics_process(false)
	linda.health_component.take_damage(5)
	_check(other.health_component.current_health == 45, "Per-instance health")
	var williams := WILLIAMS.instantiate() as Williams
	williams.acquire_player_target = false
	root.add_child(williams)
	williams.set_physics_process(false)
	_check(williams.combat_component.attack_data.attack_name == &"williams_punch", "Inherited resources do not mutate Williams")
	_check(williams.audio_component.whip_hit_player == null, "Williams retains audio routing")
	other.queue_free()
	williams.queue_free()
	await _cleanup()

	# Real overlap queries: one confirmed hit, no startup damage, correct pose,
	# mirrored geometry, and no duplicate audio on the active window.
	for direction: float in [1.0, -1.0]:
		for distance: float in [28.0, 43.0]:
			await _spawn(distance, direction)
			_check(linda._try_start_ai_attack(), "Linda starts her chosen attack")
			var attack := linda.combat_component.current_attack_data
			var is_whip := distance > linda.punch_range
			_check(attack.attack_name == (&"linda_whip" if is_whip else &"linda_punch"), "Range selects whip or punch")
			for tick: int in range(attack.startup_frames):
				_check(player.health_component.current_health == 100 and sounds.is_empty(), "Windup cannot hit or sound")
				linda._physics_process(1.0 / 60.0)
				await physics_frame
			_check(linda.visuals.animated_sprite.frame == (2 if is_whip else 1), "Contact pose at active start")
			_check(linda.visuals.animated_sprite.flip_h == (direction < 0), "Mirrored attack visual")
			for tick: int in range(attack.active_frames + attack.recovery_frames):
				linda._physics_process(1.0 / 60.0)
				await physics_frame
			_check(player.health_component.current_health == 100 - attack.damage, "Exactly one hit per attack")
			var expected_sound := linda.audio_component.whip_hit_player if is_whip else linda.audio_component.punch_hit_player
			_check(sounds == [expected_sound], "Exactly one matching impact sound")
			_check(not linda.combat_component.is_attacking, "Attack recovers")
			_check(linda.ai_component.intent == EnemyAIComponent.IDLE, "No locomotion during attack")
			await _cleanup()

	# Missing the lane, being out of reach, or being interrupted cannot hurt
	# Billy; landing/death presentation still uses the common fighter clock.
	for offset: Vector2 in [Vector2(90, 0), Vector2(43, 40)]:
		await _spawn()
		player.position = linda.position + offset
		_check(linda._try_start_ai_attack(), "Miss setup")
		for tick: int in range(linda.whip_attack.total_frames()):
			linda._physics_process(1.0 / 60.0)
			await physics_frame
		_check(player.health_component.current_health == 100 and sounds.is_empty(), "Misses are silent and harmless")
		await _cleanup()

	await _spawn()
	linda._try_start_ai_attack()
	_check(linda.hurtbox.receive_attack(HIT, Vector2.ZERO, player), "Linda accepts player hit")
	_check(not linda.combat_component.is_attacking and not linda.combat_component.is_hitbox_active, "Hit cancels whip")
	_check(linda.visuals.animated_sprite.animation == &"status1", "First hit reaction")
	linda.hurtbox.receive_attack(HIT, Vector2.ZERO, player)
	_check(linda.visuals.animated_sprite.animation == &"status2", "Second hit reaction")
	linda.hurtbox.receive_attack(HIT, Vector2.ZERO, player)
	_check(linda.visuals.animated_sprite.animation == &"knockdown", "Third hit knockdown")
	for tick: int in range(62):
		linda._physics_process(1.0 / 60.0)
		await physics_frame
	_check(not linda.hit_reaction_component.is_incapacitated(), "Linda gets up")
	linda.health_component.take_damage(999)
	linda._physics_process(1.0 / 60.0)
	_check(linda.visuals.animated_sprite.animation == &"death", "Linda death animation")
	_check(sounds.count(linda.audio_component.death_voice_player) == 1, "Linda death voice once")
	_check(linda.audio_component.death_voice_player.stream.resource_path.ends_with("voice_03_linda_dies.wav"), "Linda-specific death voice")
	_check(linda.audio_component.whip_hit_player.bus == &"SFX" and linda.audio_component.whip_hit_player.stream.resource_path.ends_with("sfx_19_whip.wav"), "Whip audio resource and bus")
	await _cleanup()

	# Live AI must approach and select its longer-range move without relying
	# on the test directly starting an attack.
	await _spawn(110)
	linda.set_physics_process(true)
	var attacked := false
	for tick: int in range(160):
		await physics_frame
		if linda.combat_component.is_attacking:
			attacked = true
			break
	_check(attacked and linda.combat_component.current_attack_data == linda.whip_attack, "Live Linda approaches and whips")
	await _cleanup()

	await _test_ending_wave()
	if failures.is_empty():
		print("LINDA_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("LINDA_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _test_ending_wave() -> void:
	var alley := ALLEY.instantiate() as PrototypeAlley
	var encounters := alley.encounter_controllers()
	var ending := encounters[2]
	var boss := encounters[3]
	encounters[0].enabled = false
	encounters[1].enabled = false
	ending.spawn_interval_frames = 1
	var clears: Array[bool] = []
	ending.encounter_cleared.connect(func() -> void: clears.append(true))
	ending.enemy_spawned.connect(func(enemy: Node2D) -> void: enemy.set_physics_process(false))
	boss.enemy_spawned.connect(func(enemy: Node2D) -> void: enemy.set_physics_process(false))
	root.add_child(alley)
	alley.player.set_physics_process(false)
	alley.player.position = Vector2(ending.lock_x, 188)
	for tick: int in range(12):
		await physics_frame
	var williams_count := 0
	var linda_count := 0
	var survivor: Linda
	for actor: Node in alley.actors.get_children():
		if actor is Williams:
			williams_count += 1
			actor.queue_free()
		elif actor is Linda:
			linda_count += 1
			survivor = actor
	_check(williams_count == 3 and linda_count == 1, "Ending has exactly 3 Williams plus 1 Linda")
	alley.player.position.x = alley.exit.position.x
	await physics_frame
	await physics_frame
	_check(ending.alive_count == 1 and ending.state == EncounterController.ACTIVE, "Linda alone holds ending open")
	_check(alley.camera.is_locked and boss.spawned_count == 0, "Linda gates camera and Abobo entrance")
	_check(alley.state == PrototypeAlley.PLAYING and alley.music.stream.resource_path.ends_with("02_slums.mp3"), "Linda keeps stage music and exit gated")
	if survivor != null:
		_check(survivor.target == alley.player, "Spawned Linda targets Billy")
		_check(survivor.position == Vector2(1184, 184), "Linda's separate right-side entrance")
		alley.player.position.x = ending.lock_x
		survivor.death_linger_frames = 20
		survivor.health_component.take_damage(999)
		survivor.set_physics_process(true)
		for tick: int in range(25):
			await physics_frame
		_check(ending.is_cleared() and ending.alive_count == 0 and clears == [true], "Linda's defeat clears once, not twice on tree exit")
		_check(not alley.camera.is_locked and boss.spawned_count == 0, "Ending unlocks before boss trigger")
		alley.player.position.x = boss.lock_x
		await physics_frame
		await physics_frame
		_check(boss.spawned_count == 1 and alley.music.stream.resource_path.ends_with("03_abobo_entrance.mp3"), "Abobo follows Linda, with boss music")
		for actor: Node in alley.actors.get_children():
			if actor is Abobo:
				actor.queue_free()
		await physics_frame
		alley.player.position.x = alley.exit.position.x
		await physics_frame
		await physics_frame
		_check(alley.state == PrototypeAlley.CLEARED, "Exit still works after Linda and Abobo")
	await AudioSettle.free_level(self, alley)
