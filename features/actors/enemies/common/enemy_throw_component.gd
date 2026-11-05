class_name EnemyThrowComponent
extends Node
## Exclusive two-actor mediator. Only the enemy ticks this clock; Billy's
## input, jump, combat and hair-grab clocks cannot compete with its poses.

const RELEASE_FRAME: int = 24
const LANDING_FRAME: int = 48
const END_FRAME: int = 56
const HOLD_DISTANCE: float = 26.0
const THROW_ANIMATION: StringName = &"throw"
const VICTIM_ANIMATION: StringName = &"being_thrown"

@export var actor: EnemyFighter
@export var attack: AttackData
@export_range(1.0, 100.0, 1.0) var reach: float = 32.0
@export_range(0.0, 20.0, 1.0) var depth_tolerance: float = 6.0
@export var travel_distance: float = 120.0

var victim: Player
var frame: int = 0
var facing: float = 1.0
var _active: bool = false
var _releasing: bool = false
var _launched: bool = false
var _landed: bool = false
var _delivering_hit: bool = false
var _baseline: Vector2
var _origin: Vector2


func _ready() -> void:
	assert(actor != null and attack != null, "Enemy throw requires actor and attack")


func _exit_tree() -> void:
	release()


func is_active() -> bool:
	return _active


func has_launched() -> bool:
	return _launched


func has_landed() -> bool:
	return _landed


func try_start(candidate: Player) -> bool:
	if (
		_active or _releasing or not is_instance_valid(candidate) or not candidate.can_be_enemy_thrown()
		or not actor.is_inside_tree() or actor.is_queued_for_deletion()
		or actor.health_component.is_dead() or actor.hit_reaction_component.is_incapacitated()
		or actor.combat_component.is_attacking or is_instance_valid(actor.grab_owner)
	):
		return false
	var gap := candidate.global_position - actor.global_position
	if absf(candidate.combat_elevation() - actor.combat_elevation()) > 16.0:
		return false
	if absf(gap.x) > reach or absf(gap.y) > depth_tolerance:
		return false
	facing = signf(gap.x) if not is_zero_approx(gap.x) else actor.ai_component.facing
	var destination := actor.global_position + Vector2(facing * HOLD_DISTANCE, 0)
	# Ignore only the paired bodies, never world walls/screen edges. Reject
	# obstructed acquisition rather than teleport a captive through geometry.
	actor.add_collision_exception_with(candidate)
	candidate.add_collision_exception_with(actor)
	if candidate.test_move(candidate.global_transform, destination - candidate.global_position):
		actor.remove_collision_exception_with(candidate)
		candidate.remove_collision_exception_with(actor)
		return false
	victim = candidate
	_baseline = victim.visuals.position
	frame = 0
	_active = true
	_launched = false
	_landed = false
	victim.tree_exiting.connect(release)
	actor.tree_exiting.connect(release)
	victim.move_and_collide(destination - victim.global_position)
	actor.ai_component.facing = facing
	actor.combat_component.set_facing(facing)
	actor.movement_component.stop()
	actor.state_machine.transition_to(EnemyStateMachine.THROW)
	# State observers can synchronously kill/remove either actor even during
	# acquisition. Never claim a victim after that callback released the pair.
	if not _active:
		return false
	victim.claim_enemy_throw(self)
	if not _active:
		return false
	if not _pair_is_valid():
		release()
		return false
	sync_visuals()
	# Acquisition callbacks and ownership validation have confirmed the pair.
	actor.audio_component.play_attack_voice(attack)
	return true


func _pair_is_valid() -> bool:
	return not (
		not is_instance_valid(victim) or not victim.is_inside_tree() or victim.is_queued_for_deletion()
		or victim.throw_owner != self or victim.is_dead() or actor.health_component.is_dead()
		or actor.is_queued_for_deletion() or not actor.is_inside_tree()
		or victim.hit_reaction_component.is_incapacitated() or actor.hit_reaction_component.is_incapacitated()
		or victim.combat_component.is_attacking or actor.combat_component.is_attacking
		or victim.jump_component.is_airborne or victim.is_elevated()
		or victim.state_machine.current_state != PlayerStateMachine.THROWN
		or actor.state_machine.current_state != EnemyStateMachine.THROW
	)


func physics_tick() -> void:
	if not _active:
		return
	if not _pair_is_valid():
		release()
		return
	actor.movement_component.stop()
	victim.movement_component.stop()
	frame += 1
	if frame == RELEASE_FRAME:
		_launched = true
		_origin = victim.global_position
		victim.hit_reaction_component.begin_external_fall()
	if _launched and not _landed:
		var progress := clampf(float(frame - RELEASE_FRAME) / float(LANDING_FRAME - RELEASE_FRAME), 0, 1)
		var destination := _origin + Vector2(-facing * travel_distance * progress, 0)
		victim.move_and_collide(destination - victim.global_position)
		victim.visuals.position = _baseline + Vector2.UP * (42.0 * (1.0 - progress) + sin(progress * PI) * 26.0)
	elif not _launched:
		victim.visuals.position = _baseline + Vector2.UP * (42.0 * clampf(float(frame - 8) / 16.0, 0, 1))
	victim.jump_component.sync_ground_position()
	if frame == LANDING_FRAME:
		_landed = true
		victim.visuals.position = _baseline
		sync_visuals()
		victim.hit_reaction_component.report_ground_landing()
		if not _active:
			return
		# Damage is committed once on ground contact. Even lethal throws show
		# the entire flight, and death starts prone without a second fall.
		_delivering_hit = true
		var hit := victim.hurtbox.receive_attack(attack, Vector2.ZERO, actor)
		_delivering_hit = false
		if hit:
			actor.audio_component.play_attack_hit(attack)
		if not _active:
			return
	if frame >= END_FRAME:
		release()
		return
	sync_visuals()


func is_paired_hit(source: Node2D, received_attack: AttackData) -> bool:
	return _delivering_hit and source == actor and received_attack == attack


## Clear ownership BEFORE callbacks. Interrupted flight snaps to a single
## landing and recoverable prone state; interruption before release is free.
func release(recover_victim: bool = true) -> void:
	if not _active:
		return
	_releasing = true
	var released := victim
	var was_launched := _launched
	victim = null
	_active = false
	if is_instance_valid(actor) and actor.tree_exiting.is_connected(release):
		actor.tree_exiting.disconnect(release)
	if is_instance_valid(released):
		if released.tree_exiting.is_connected(release):
			released.tree_exiting.disconnect(release)
		if is_instance_valid(actor):
			actor.remove_collision_exception_with(released)
			released.remove_collision_exception_with(actor)
		released.visuals.position = _baseline
		if was_launched:
			released.hit_reaction_component.finish_external_fall(_landed)
		released.release_enemy_throw(self, was_launched and recover_victim, attack)
	if is_instance_valid(actor):
		actor.ai_component.notify_attack_finished()
		if not actor.health_component.is_dead() and not actor.hit_reaction_component.is_incapacitated():
			actor.state_machine.transition_to(EnemyStateMachine.IDLE)
			actor._sync_visuals()
	_launched = false
	_landed = false
	_releasing = false


func sync_visuals() -> void:
	if not _active or not is_instance_valid(victim):
		return
	actor.visuals.sync_scheduled_pose(THROW_ANIMATION, frame, PackedInt32Array([0, 8, 16, 24]), facing)
	if frame < 16:
		victim.visuals.sync_grab_pose(&"hurt", 0, -facing)
	else:
		var pose := 2 if _landed else (1 if frame >= 32 else 0)
		victim.visuals.sync_grab_pose(VICTIM_ANIMATION, pose, facing)
