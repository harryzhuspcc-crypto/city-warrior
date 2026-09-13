class_name HitReactionComponent
extends Node

signal reaction_started(reaction: StringName, attack_data: AttackData)
signal recovered

const NONE: StringName = &"none"
const HITSTUN: StringName = &"hitstun"
const KNOCKDOWN: StringName = &"knockdown"
const DEATH: StringName = &"death"

@export var movement_component: MovementComponent
## Knockdown and death make this hurtbox invulnerable until recovery.
@export var hurtbox: HurtboxComponent

var current_reaction: StringName = NONE
var reaction_frame: int = 0
var reaction_frames_total: int = 0
var consecutive_hits: int = 0

var _knockback: Vector2 = Vector2.ZERO
var _knockback_frames: int = 0
var _chain_reset_frames_remaining: int = 0
var _knockdown_frames: int = 60
var _hits_before_knockdown: int = 3
var _hit_chain_reset_frames: int = 30
var _knockdown_knockback_scale: float = 1.5


func _ready() -> void:
	assert(movement_component != null, "HitReactionComponent requires MovementComponent")
	assert(hurtbox != null, "HitReactionComponent requires HurtboxComponent")


func configure(stats: FighterStats) -> void:
	assert(stats != null, "HitReactionComponent requires FighterStats")
	_knockdown_frames = stats.knockdown_frames
	_hits_before_knockdown = stats.hits_before_knockdown
	_hit_chain_reset_frames = stats.hit_chain_reset_frames
	_knockdown_knockback_scale = stats.knockdown_knockback_scale


## Chooses hitstun, knockdown, or death for a confirmed hit and starts it.
## Returns the selected reaction.
func apply_hit(
	attack_data: AttackData,
	knockback: Vector2,
	lethal: bool = false,
	force_knockdown: bool = false
) -> StringName:
	assert(attack_data != null, "HitReactionComponent requires AttackData for a hit")
	consecutive_hits += 1
	_chain_reset_frames_remaining = 0

	var reaction := HITSTUN
	if lethal:
		reaction = DEATH
	elif (
		force_knockdown
		or attack_data.knocks_down
		or consecutive_hits >= _hits_before_knockdown
	):
		reaction = KNOCKDOWN

	if reaction == DEATH:
		begin_death(knockback, attack_data)
		return reaction

	current_reaction = reaction
	reaction_frame = 0
	if reaction == HITSTUN:
		reaction_frames_total = maxi(attack_data.hitstun_frames, 1)
		_knockback = knockback
		_knockback_frames = reaction_frames_total
	else:
		reaction_frames_total = maxi(_knockdown_frames, 1)
		consecutive_hits = 0
		_knockback = knockback * _knockdown_knockback_scale
		_knockback_frames = maxi(_knockdown_frames / 3, 1)
	_set_invulnerable(reaction != HITSTUN)
	reaction_started.emit(reaction, attack_data)
	return reaction


## Starts the permanent death reaction. Lethal hits route here through
## apply_hit(); orchestrators call it directly when health reaches zero
## without a hurtbox hit so the fall still plays and lingering still counts.
func begin_death(knockback: Vector2 = Vector2.ZERO, attack_data: AttackData = null) -> void:
	if current_reaction == DEATH:
		return
	current_reaction = DEATH
	reaction_frame = 0
	reaction_frames_total = maxi(_knockdown_frames, 1)
	consecutive_hits = 0
	_knockback = knockback * _knockdown_knockback_scale
	_knockback_frames = maxi(_knockdown_frames / 3, 1)
	_set_invulnerable(true)
	reaction_started.emit(DEATH, attack_data)


func physics_tick() -> void:
	if current_reaction == NONE:
		if _chain_reset_frames_remaining > 0:
			_chain_reset_frames_remaining -= 1
			if _chain_reset_frames_remaining == 0:
				consecutive_hits = 0
		return

	if reaction_frame < _knockback_frames and not _knockback.is_zero_approx():
		var remaining_ratio := 1.0 - float(reaction_frame) / float(_knockback_frames)
		movement_component.move_at_speed(
			_knockback.normalized(),
			_knockback.length() * remaining_ratio
		)
	else:
		movement_component.stop()

	reaction_frame += 1
	if current_reaction == DEATH:
		return
	if reaction_frame >= reaction_frames_total:
		current_reaction = NONE
		if _hit_chain_reset_frames > 0:
			_chain_reset_frames_remaining = _hit_chain_reset_frames
		else:
			consecutive_hits = 0
		_set_invulnerable(false)
		recovered.emit()


func is_incapacitated() -> bool:
	return current_reaction != NONE


func is_knocked_down() -> bool:
	return current_reaction == KNOCKDOWN or current_reaction == DEATH


func reset() -> void:
	current_reaction = NONE
	reaction_frame = 0
	reaction_frames_total = 0
	consecutive_hits = 0
	_knockback = Vector2.ZERO
	_knockback_frames = 0
	_chain_reset_frames_remaining = 0
	_set_invulnerable(false)


func _set_invulnerable(invulnerable: bool) -> void:
	hurtbox.is_invulnerable = invulnerable
