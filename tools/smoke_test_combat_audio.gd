extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")
const WILLIAMS_SCENE: PackedScene = preload(
	"res://features/actors/enemies/williams/williams.tscn"
)
const AudioSettle = preload("res://tools/lib/audio_settle.gd")


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
