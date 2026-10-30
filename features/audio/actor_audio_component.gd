class_name ActorAudioComponent
extends Node
## Actor-local combat audio. Combat and health own gameplay; this presentation
## component only listens to their signals and selects an already-pooled player.

signal playback_requested(player: AudioStreamPlayer2D)

@export var combat_component: CombatComponent
@export var health_component: HealthComponent
@export var hit_reaction_component: HitReactionComponent
@export var ground_fall_player: AudioStreamPlayer2D
@export var punch_hit_player: AudioStreamPlayer2D
@export var kick_hit_player: AudioStreamPlayer2D
@export var whip_hit_player: AudioStreamPlayer2D
@export var action_voice_player: AudioStreamPlayer2D
@export var death_voice_player: AudioStreamPlayer2D


func _ready() -> void:
	assert(health_component != null, "ActorAudioComponent requires HealthComponent")
	health_component.died.connect(play_death_voice)
	if hit_reaction_component != null:
		hit_reaction_component.ground_landed.connect(play_ground_fall)
	_validate_player(ground_fall_player, &"SFX")
	if combat_component != null:
		combat_component.attack_started.connect(_on_attack_started)
		combat_component.hit_landed.connect(_on_hit_landed)
	_validate_player(punch_hit_player, &"SFX")
	_validate_player(kick_hit_player, &"SFX")
	_validate_player(whip_hit_player, &"SFX")
	_validate_player(action_voice_player, &"Voice")
	_validate_player(death_voice_player, &"Voice")


## Plays only after CombatComponent confirms contact, so missed attacks stay
## silent instead of producing a misleading hit sound.
func play_attack_hit(attack_data: AttackData) -> void:
	if attack_data == null:
		return
	match attack_data.impact_sound:
		AttackData.ImpactSound.PUNCH:
			_play(punch_hit_player)
		AttackData.ImpactSound.KICK:
			_play(kick_hit_player)
		AttackData.ImpactSound.WHIP:
			_play(whip_hit_player)


func play_attack_voice(attack_data: AttackData) -> void:
	if attack_data != null and attack_data.plays_action_voice:
		_play(action_voice_player)


func play_ground_fall() -> void:
	_play(ground_fall_player)


func play_death_voice() -> void:
	_play(death_voice_player)


func _on_attack_started() -> void:
	play_attack_voice(combat_component.current_attack_data)


func _on_hit_landed(
	_target: HurtboxComponent,
	attack_data: AttackData,
	_knockback: Vector2
) -> void:
	play_attack_hit(attack_data)


func _play(player: AudioStreamPlayer2D) -> void:
	if player != null:
		playback_requested.emit(player)
		# Headless smoke suites have no listener and may exit before the dummy
		# audio thread releases a new playback. The request signal still makes
		# routing fully testable without leaking audio resources at teardown.
		if DisplayServer.get_name() != "headless":
			player.play()


func _validate_player(player: AudioStreamPlayer2D, expected_bus: StringName) -> void:
	if player == null:
		return
	assert(player.stream != null, "%s player requires an AudioStream" % expected_bus)
	assert(player.bus == expected_bus, "%s player must route to its own bus" % expected_bus)
