extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")
const WILLIAMS_SCENE: PackedScene = preload(
	"res://features/actors/enemies/williams/williams.tscn"
)
const AudioSettle = preload("res://tools/lib/audio_settle.gd")

var _fall_failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for bus_name: StringName in [&"Music", &"SFX", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Missing dedicated %s audio bus" % bus_name)
			return

	var player := PLAYER_SCENE.instantiate() as Player
	root.add_child(player)
	await physics_frame
	player.set_physics_process(false)
	var audio := player.audio_component
	if audio == null:
		_fail("Player is missing ActorAudioComponent")
		return
	var requested_players: Array[AudioStreamPlayer2D] = []
	audio.playback_requested.connect(
		func(requested: AudioStreamPlayer2D) -> void: requested_players.append(requested)
	)

	var punch_attacks: Array[AttackData] = [
		player.combat_component.attack_data,
		player.punch_cross_attack_data,
		player.uppercut_attack_data,
		player.elbow_attack_data,
	]
	for attack: AttackData in punch_attacks:
		if attack.impact_sound != AttackData.ImpactSound.PUNCH:
			_fail("%s must use the punch impact" % attack.attack_name)
			return

	var kick_attacks: Array[AttackData] = [
		player.kick_attack_data,
		player.turn_kick_attack_data,
		player.back_kick_attack_data,
		player.head_attack_data,
		player.jump_kick_attack_data,
	]
	for attack: AttackData in kick_attacks:
		if attack.impact_sound != AttackData.ImpactSound.KICK:
			_fail("%s must use the kick impact" % attack.attack_name)
			return
	if player.head_attack_data.impact_sound != player.kick_attack_data.impact_sound:
		_fail("Head attack must share the kick sound")
		return
	if not player.elbow_attack_data.plays_action_voice:
		_fail("Elbow must use Billy's action voice")
		return
	if not player.back_kick_attack_data.plays_action_voice:
		_fail("Back kick must use Billy's action voice")
		return
	if player.head_attack_data.plays_action_voice or player.jump_kick_attack_data.plays_action_voice:
		_fail("Billy's action voice must be limited to elbow and back kick")
		return

	if not _stream_is(audio.punch_hit_player, "sfx_08_punch_hit.wav", &"SFX"):
		_fail("Player punch impact is not wired to SFX 08 on the SFX bus")
		return
	if not _stream_is(audio.kick_hit_player, "sfx_09_kick_hit.wav", &"SFX"):
		_fail("Player kick impact is not wired to SFX 09 on the SFX bus")
		return
	if not _stream_is(
		audio.action_voice_player,
		"voice_01_billy_jimmy_elbow_or_back_kick.wav",
		&"Voice"
	):
		_fail("Elbow/back-kick voice is not wired to Voice 01")
		return
	if not _stream_is(audio.death_voice_player, "voice_04_player_dies.wav", &"Voice"):
		_fail("Player death is not wired to Voice 04")
		return

	# Impact audio is driven by confirmed-hit signals, not attack startup.
	requested_players.clear()
	player.combat_component.hit_landed.emit(
		null,
		player.combat_component.attack_data,
		Vector2.ZERO
	)
	if requested_players != [audio.punch_hit_player]:
		_fail("A confirmed punch did not start its impact sound")
		return
	requested_players.clear()
	player.combat_component.hit_landed.emit(null, player.head_attack_data, Vector2.ZERO)
	if requested_players != [audio.kick_hit_player]:
		_fail("A confirmed head attack did not start the shared kick sound")
		return

	requested_players.clear()
	if not player.combat_component.try_start_attack(player.elbow_attack_data):
		_fail("Could not start elbow for its voice integration check")
		return
	if requested_players != [audio.action_voice_player]:
		_fail("Starting elbow did not start Voice 01")
		return
	player.combat_component.cancel_attack()

	requested_players.clear()
	player.health_component.take_damage(player.health_component.current_health)
	if requested_players != [audio.death_voice_player]:
		_fail("Player death did not start Voice 04")
		return

	var enemy := WILLIAMS_SCENE.instantiate() as Williams
	enemy.acquire_player_target = false
	root.add_child(enemy)
	await physics_frame
	enemy.set_physics_process(false)
	var enemy_requests: Array[AudioStreamPlayer2D] = []
	enemy.audio_component.playback_requested.connect(
		func(requested: AudioStreamPlayer2D) -> void: enemy_requests.append(requested)
	)
	if not _stream_is(
		enemy.audio_component.death_voice_player,
		"voice_02_male_enemy_dies.wav",
		&"Voice"
	):
		_fail("Enemy death is not wired to Voice 02")
		return
	if not _stream_is(enemy.audio_component.punch_hit_player, "sfx_08_punch_hit.wav", &"SFX"):
		_fail("Enemy punch is not wired to SFX 08")
		return
	enemy.health_component.take_damage(enemy.health_component.current_health)
	if enemy_requests != [enemy.audio_component.death_voice_player]:
		_fail("Enemy death did not start Voice 02")
		return

	await AudioSettle.settle(self)
	root.remove_child(player)
	player.free()
	root.remove_child(enemy)
	enemy.free()
	await AudioSettle.settle(self)
	_test_fall_audio()
	await AudioSettle.settle(self)
	if _fall_failures > 0:
		quit(1)
		return
	print("COMBAT_AUDIO_SMOKE_TEST_PASS")
	quit()


func _stream_is(player: AudioStreamPlayer2D, suffix: String, bus_name: StringName) -> bool:
	return (
		player != null
		and player.stream != null
		and player.stream.resource_path.ends_with(suffix)
		and player.bus == bus_name
	)


func _fail(message: String) -> void:
	push_error("COMBAT_AUDIO_SMOKE_TEST_FAIL: %s" % message)
	quit(1)


# No wall-clock waits: only the real actor orchestrator advances reaction time.
# Fresh, passive actors isolate health, input, AI and audio request histories.
func _fall_actor(scene: PackedScene) -> Variant:
	var actor = scene.instantiate()
	if actor is Williams:
		actor.acquire_player_target = false
	root.add_child(actor)
	actor.set_physics_process(false)
	return actor


func _check_fall(condition: bool, message: String) -> void:
	if not condition:
		_fall_failures += 1
		push_error("COMBAT_AUDIO_SMOKE_TEST_FAIL: " + message)


func _observe_fall(actor: Variant) -> Dictionary:
	var observed := {"requests": [], "frames": []}
	actor.audio_component.playback_requested.connect(
		func(requested: AudioStreamPlayer2D) -> void:
			observed.requests.append(requested)
	)
	actor.hit_reaction_component.ground_landed.connect(
		func() -> void: observed.frames.append(actor.hit_reaction_component.reaction_frame)
	)
	_check_fall(
		_stream_is(actor.audio_component.ground_fall_player, "sfx_10_fall_to_the_ground.wav", &"SFX"),
		"%s ground fall must use SFX 10 on SFX" % actor.name
	)
	_check_fall(actor.hit_reaction_component.fall_landing_frame == 16,
		"%s landing default must be exactly 16" % actor.name)
	return observed


func _tick_actor(actor: Variant, frames: int = 1) -> void:
	for frame in range(frames):
		actor._physics_process(1.0 / 60.0)


func _fall_count(actor: Variant, observed: Dictionary) -> int:
	return observed.requests.count(actor.audio_component.ground_fall_player)


func _receive(actor: Variant, attack: AttackData, label: String) -> void:
	_check_fall(actor.hurtbox.receive_attack(attack, Vector2(30, 0), null),
		label + ": hurtbox must accept hit")


func _assert_landing(actor: Variant, observed: Dictionary, label: String, previous: int = 0) -> void:
	var reaction: HitReactionComponent = actor.hit_reaction_component
	_check_fall(_fall_count(actor, observed) == previous, label + ": no fall sound at startup")
	while reaction.reaction_frame < 15:
		_tick_actor(actor)
		_check_fall(_fall_count(actor, observed) == previous,
			label + ": premature sound at frame %d" % reaction.reaction_frame)
		_check_fall(observed.frames.size() == previous, label + ": premature ground_landed")
	_tick_actor(actor)
	_check_fall(reaction.reaction_frame == 16, label + ": actor must reach frame 16")
	_check_fall(_fall_count(actor, observed) == previous + 1, label + ": exactly one SFX at frame 16")
	_check_fall(observed.frames.size() == previous + 1 and observed.frames.back() == 16,
		label + ": ground_landed exactly once at frame 16")
	# Includes the entire prone/get-up interval and additional recovered ticks;
	# death remains below Williams' authored despawn frame (90).
	_tick_actor(actor, 64)
	_check_fall(_fall_count(actor, observed) == previous + 1,
		label + ": duplicate sound during lingering/recovery")
	_check_fall(observed.frames.size() == previous + 1,
		label + ": duplicate ground_landed during lingering/recovery")


func _test_fall_audio() -> void:
	var jab := AttackData.new()
	jab.damage = 1
	jab.hitstun_frames = 12
	var finisher := jab.duplicate() as AttackData
	finisher.knocks_down = true
	for scene: PackedScene in [PLAYER_SCENE, WILLIAMS_SCENE]:
		var actor = _fall_actor(scene)
		var label: String = "Player" if actor is Player else "Williams"
		var observed := _observe_fall(actor)
		for hit in range(3):
			_receive(actor, jab, label + " three-hit")
			var expected := HitReactionComponent.KNOCKDOWN
			if hit < 2:
				expected = HitReactionComponent.HITSTUN
				if actor is Williams:
					expected = HitReactionComponent.STATUS1 if hit == 0 else HitReactionComponent.STATUS2
			_check_fall(actor.hit_reaction_component.current_reaction == expected,
				label + ": wrong three-hit reaction at hit %d" % (hit + 1))
			_check_fall(observed.requests.is_empty(), label + ": hit startup must not request SFX")
			if hit < 2:
				_tick_actor(actor, 2)
		_assert_landing(actor, observed, label + " three-hit")
		_check_fall(not actor.hit_reaction_component.is_incapacitated(), label + ": must recover")
		_receive(actor, finisher, label + " second fall after recovery")
		_check_fall(actor.hit_reaction_component.current_reaction == HitReactionComponent.KNOCKDOWN,
			label + ": forced finisher must knock down")
		_assert_landing(actor, observed, label + " second fall after recovery", 1)
		actor.hit_reaction_component.reset()
		_receive(actor, finisher, label + " after reset")
		_assert_landing(actor, observed, label + " after reset", 2)
		actor.free()

		for lethal_hurtbox in [false, true]:
			actor = _fall_actor(scene)
			observed = _observe_fall(actor)
			var death_label := label + (" lethal hurtbox" if lethal_hurtbox else " direct health death")
			if lethal_hurtbox:
				var lethal := jab.duplicate() as AttackData
				lethal.damage = actor.health_component.current_health
				_receive(actor, lethal, death_label)
			else:
				actor.health_component.take_damage(actor.health_component.current_health)
			_check_fall(observed.requests == [actor.audio_component.death_voice_player],
				death_label + ": startup must request death voice only")
			_assert_landing(actor, observed, death_label)
			_check_fall(actor.hit_reaction_component.current_reaction == HitReactionComponent.DEATH,
				death_label + ": death must remain permanent")
			_check_fall(observed.requests.count(actor.audio_component.death_voice_player) == 1,
				death_label + ": death voice must not repeat")
			actor.free()

		for death_frame in [7, 20]:
			actor = _fall_actor(scene)
			observed = _observe_fall(actor)
			_receive(actor, finisher, label)
			_tick_actor(actor, death_frame)
			var before: int = _fall_count(actor, observed)
			actor.health_component.take_damage(actor.health_component.current_health)
			_check_fall(_fall_count(actor, observed) == before, label + ": death during fall/prone startup silent")
			_tick_actor(actor)
			_check_fall(actor.hit_reaction_component.reaction_frame == death_frame + 1,
				label + ": death must continue existing fall clock")
			if death_frame < 16:
				_assert_landing(actor, observed, label + " death mid-fall")
			else:
				_tick_actor(actor, 58)
				_check_fall(_fall_count(actor, observed) == 1 and observed.frames == [16],
					label + ": prone death must not replay landing")
			actor.free()

	var player = _fall_actor(PLAYER_SCENE)
	var observed := _observe_fall(player)
	_check_fall(player.jump_component.try_jump(), "Airborne hit: jump must start")
	_tick_actor(player, 3)
	_check_fall(player.jump_component.is_airborne, "Airborne hit: must be airborne before hit")
	_receive(player, jab, "Airborne player")
	_check_fall(not player.jump_component.is_airborne and
		player.hit_reaction_component.current_reaction == HitReactionComponent.KNOCKDOWN,
		"Airborne ordinary jab must force knockdown")
	_assert_landing(player, observed, "Airborne player")
	player.free()

	for move: String in ["jump", "backkick", "jumpkick"]:
		player = _fall_actor(PLAYER_SCENE)
		observed = _observe_fall(player)
		var landings: Array[int] = []
		player.jump_component.landed.connect(func() -> void: landings.append(1))
		if move != "backkick":
			_check_fall(player.jump_component.try_jump(), move + ": jump must start")
			_tick_actor(player, 3)
		if move != "jump":
			var attack: AttackData = player.back_kick_attack_data if move == "backkick" else player.jump_kick_attack_data
			_check_fall(player._start_attack(attack), move + ": actual actor attack must start")
		_check_fall(player.jump_component.is_airborne, move + ": must exercise airborne landing")
		_tick_actor(player, 180)
		_check_fall(not player.jump_component.is_airborne and landings.size() == 1,
			move + ": must actually land once")
		_check_fall(_fall_count(player, observed) == 0 and observed.frames.is_empty(),
			move + ": ordinary landing must not request fall SFX or ground_landed")
		player.free()
