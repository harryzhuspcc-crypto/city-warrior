class_name HitReactionComponent
extends Node

signal reaction_started(reaction: StringName, attack_data: AttackData)
signal recovered
signal ground_landed

const NONE: StringName = &"none"
const HITSTUN: StringName = &"hitstun"
const STATUS1: StringName = &"status1"
const STATUS2: StringName = &"status2"
const KNOCKDOWN: StringName = &"knockdown"
const DEATH: StringName = &"death"

@export var movement_component: MovementComponent
## Knockdown and death make this hurtbox invulnerable until recovery.
@export var hurtbox: HurtboxComponent

var current_reaction: StringName = NONE
var reaction_frame: int = 0
var reaction_frames_total: int = 0
var consecutive_hits: int = 0
## Horizontal travel of the fall. Native actor fall art tips left, so visuals
## face opposite this direction; targeting/facing of the attacker is untouched.
var fall_direction: float = 0.0
var fall_landing_frame: int = 16
var _fall_pending: bool = false

var _staged: bool = false
var _status1_frames: int = 30
var _status2_frames: int = 60
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
	fall_landing_frame = mini(stats.fall_landing_frame, maxi(stats.knockdown_frames, 1))
	_staged = stats.staged_hit_reactions
	_status1_frames = stats.status1_frames
	_status2_frames = stats.status2_frames
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
	force_knockdown: bool = false,
	fall_already_landed: bool = false
) -> StringName:
	assert(attack_data != null, "HitReactionComponent requires AttackData for a hit")
	if _staged:
		# The active pose, not a post-recovery combo timer, owns progression.
		consecutive_hits = 0
		if current_reaction == STATUS1:
			consecutive_hits = 1
		elif current_reaction == STATUS2:
			consecutive_hits = 2
	consecutive_hits += 1
	_chain_reset_frames_remaining = 0

	var reaction := HITSTUN
	if _staged:
		reaction = STATUS2 if consecutive_hits == 2 else STATUS1
	if lethal:
		reaction = DEATH
	elif (
		force_knockdown
		or attack_data.knocks_down
		or consecutive_hits >= (3 if _staged else _hits_before_knockdown)
	):
		reaction = KNOCKDOWN

	if reaction == DEATH:
		begin_death(knockback, attack_data, fall_already_landed)
		return reaction

	current_reaction = reaction
	reaction_frame = 0
	_fall_pending = reaction == KNOCKDOWN and not fall_already_landed
	fall_direction = signf(knockback.x) if reaction == KNOCKDOWN else 0.0
	if reaction == KNOCKDOWN and fall_already_landed:
		reaction_frame = fall_landing_frame
	if reaction in [HITSTUN, STATUS1, STATUS2]:
		reaction_frames_total = maxi(attack_data.hitstun_frames, 1)
		if reaction == STATUS1:
			reaction_frames_total = _status1_frames
		elif reaction == STATUS2:
			reaction_frames_total = _status2_frames
		_knockback = knockback
		# A brief recoil leaves a practical walking-contact grab window.
		_knockback_frames = mini(reaction_frames_total, 6) if _staged else reaction_frames_total
	else:
		reaction_frames_total = maxi(_knockdown_frames, 1)
		consecutive_hits = 0
		_knockback = knockback * _knockdown_knockback_scale
		_knockback_frames = maxi(_knockdown_frames / 3, 1)
	_set_invulnerable(reaction == KNOCKDOWN)
	reaction_started.emit(reaction, attack_data)
	return reaction


## Starts the permanent death reaction. Lethal hits route here through
## apply_hit(); orchestrators call it directly when health reaches zero
## without a hurtbox hit so the fall still plays and lingering still counts.
func begin_death(
	knockback: Vector2 = Vector2.ZERO,
	attack_data: AttackData = null,
	fall_already_landed: bool = false
) -> void:
	if current_reaction == DEATH:
		return
	# Dying during an existing fall/prone hold must not restart its landing.
	var continuing_fall := current_reaction == KNOCKDOWN
	current_reaction = DEATH
	if not continuing_fall:
		reaction_frame = 0
		_fall_pending = true
		fall_direction = signf(knockback.x)
	if fall_already_landed:
		reaction_frame = fall_landing_frame
		_fall_pending = false
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
	if is_knocked_down() and reaction_frame >= fall_landing_frame:
		report_ground_landing()
	if current_reaction == DEATH:
		return
	if reaction_frame >= reaction_frames_total:
		current_reaction = NONE
		if not _staged and _hit_chain_reset_frames > 0:
			_chain_reset_frames_remaining = _hit_chain_reset_frames
		else:
			consecutive_hits = 0
		_set_invulnerable(false)
		recovered.emit()


## Hair throws own their arc instead of the ordinary reaction clock.
func begin_external_fall() -> void:
	_fall_pending = true


## A paired fall may be interrupted by a direct reaction, which has already
## armed its own ordinary landing. Retire that fall without replaying either
## its poses or a ground event the pair previously reported.
func finish_external_fall(already_reported: bool) -> void:
	if already_reported:
		_fall_pending = false
	else:
		report_ground_landing()
	if is_knocked_down():
		reaction_frame = maxi(reaction_frame, fall_landing_frame)


## Idempotent across prone holds, repeated ticks and throw/reaction handoff.
func report_ground_landing() -> void:
	if not _fall_pending:
		return
	_fall_pending = false
	ground_landed.emit()


func is_incapacitated() -> bool:
	return current_reaction != NONE


func is_knocked_down() -> bool:
	return current_reaction == KNOCKDOWN or current_reaction == DEATH


func reset() -> void:
	_fall_pending = false
	fall_direction = 0.0
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
