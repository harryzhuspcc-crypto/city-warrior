class_name HairGrabComponent
extends Node
## Feature-local mediator. Owns one exclusive pair and its physics-frame clock.
## References are cleared BEFORE calling either actor during release.

signal grab_started
signal grab_finished

const INACTIVE: StringName = &"inactive"
const HOLD: StringName = &"hold"
const KNEE: StringName = &"knee"
const THROW: StringName = &"throw"
const ENTRY_FRAMES: int = 8
const KNEE_HIT_FRAME: int = 4
const KNEE_FRAMES: int = 20
const THROW_FRAMES: int = 40
const THROW_LANDING_FRAME: int = 32
const HOLD_SPACING: float = 30.0

@export var player: Player
@export var knee_attack: AttackData
@export var throw_attack: AttackData

var victim: Williams
var phase: StringName = INACTIVE
var frame: int = 0
var facing: float = 1.0
var _victim_visual_position: Vector2
var _throw_origin: Vector2
var _delivering_hit: bool = false


func _ready() -> void:
	assert(player != null and knee_attack != null and throw_attack != null)


func _exit_tree() -> void:
	release()


func is_active() -> bool:
	return phase != INACTIVE


func has_landed() -> bool:
	return phase == THROW and frame >= THROW_LANDING_FRAME


## Called after ordinary walking, so slide contact (not attack reach) claims
## the victim. Stationary overlap, walking away and depth-only contact cannot.
func try_contact(direction: Vector2) -> bool:
	if is_active() or not player.can_hair_grab() or is_zero_approx(direction.x):
		return false
	for index: int in range(player.get_slide_collision_count()):
		var enemy := player.get_slide_collision(index).get_collider() as Williams
		if enemy == null or not enemy.can_be_hair_grabbed():
			continue
		var gap := enemy.global_position - player.global_position
		if gap.x * direction.x <= 0.0 or absf(gap.x) > 18.0 or absf(gap.y) > 6.0:
			continue
		return _begin(enemy, signf(direction.x))
	return false


func _begin(enemy: Williams, direction: float) -> bool:
	if not player.can_hair_grab() or not enemy.can_be_hair_grabbed():
		return false
	# Open the pair to the authored hand/head spacing without teleporting
	# through walls or other bodies. At a wall, Billy steps back instead.
	var destination := player.global_position + Vector2(HOLD_SPACING * direction, 0.0)
	if enemy.test_move(enemy.global_transform, destination - enemy.global_position):
		var player_destination := enemy.global_position - Vector2(HOLD_SPACING * direction, 0.0)
		if player.test_move(player.global_transform, player_destination - player.global_position):
			return false
		player.move_and_collide(player_destination - player.global_position)
		destination = enemy.global_position
	victim = enemy
	phase = HOLD
	frame = 0
	facing = direction
	_victim_visual_position = victim.visuals.position
	player.add_collision_exception_with(victim)
	victim.add_collision_exception_with(player)
	victim.move_and_collide(destination - victim.global_position)
	victim.tree_exiting.connect(release)
	victim.claim_hair_grab(self)
	# Actor lifecycle signals can synchronously interrupt acquisition too.
	if not is_active() or not is_instance_valid(victim) or victim.is_queued_for_deletion():
		release()
		return false
	player.input_component.clear_buffered_actions()
	player.attack_chain_component.reset()
	player.combat_component.set_facing(facing)
	player.velocity = Vector2.ZERO
	grab_started.emit()
	sync_visuals()
	return is_active()


func physics_tick() -> void:
	if not is_active():
		return
	if (
		not is_instance_valid(victim) or victim.is_queued_for_deletion()
		or not victim.is_inside_tree() or victim.grab_owner != self
		or player.is_dead() or victim.health_component.is_dead()
		or player.hit_reaction_component.is_incapacitated()
		or victim.hit_reaction_component.is_incapacitated()
		or player.is_elevated() or player.jump_component.is_airborne
		or player.combat_component.is_attacking or victim.combat_component.is_attacking
		or player.state_machine.current_state != PlayerStateMachine.GRAB
		or victim.state_machine.current_state != EnemyStateMachine.GRABBED
	):
		release()
		return
	player.movement_component.stop()
	if phase == HOLD:
		# Entry poses may be cut short by a fresh command. Waiting eight ticks
		# here would expire the normal eight-tick buffer and drop early knees.
		var action := player.input_component.consume_grab_action()
		if action == &"knee":
			phase = KNEE
			frame = 0
		elif action == &"throw":
			phase = THROW
			frame = 0
			_throw_origin = victim.global_position
	elif phase != HOLD:
		# Do not buffer attacks out of a knee/throw into ordinary combat.
		player.input_component.clear_buffered_actions()

	if phase == KNEE and frame == KNEE_HIT_FRAME:
		_deliver(knee_attack)
		if not is_active():
			return
	if phase == THROW:
		if frame == 8:
			victim.hit_reaction_component.begin_external_fall()
			_deliver(throw_attack)
			if not is_active():
				return
	frame += 1
	if phase == THROW and frame >= 8 and frame <= THROW_LANDING_FRAME:
		# Use the same frame as sync_visuals: the prone pose, ground height,
		# and landing event must agree. Physics still respects world walls.
		var progress := float(frame - 8) / float(THROW_LANDING_FRAME - 8)
		var destination := _throw_origin + Vector2(-facing * 100.0 * progress, 0.0)
		victim.move_and_collide(destination - victim.global_position)
		victim.visuals.position = _victim_visual_position + Vector2(0.0, -sin(progress * PI) * 35.0)
		if frame == THROW_LANDING_FRAME:
			victim.visuals.position = _victim_visual_position
			sync_visuals()
			victim.hit_reaction_component.report_ground_landing()
			if not is_active():
				return
	if phase == KNEE and frame >= KNEE_FRAMES:
		phase = HOLD
		frame = ENTRY_FRAMES
	elif phase == THROW and frame >= THROW_FRAMES:
		var landed := victim
		release()
		if is_instance_valid(landed) and not landed.health_component.is_dead():
			landed.finish_hair_throw(throw_attack)
		return
	sync_visuals()


## The normal hurtbox/health path still owns damage and lethal signals. Only
## this exact paired hit suppresses ordinary status progression/interruption.
func is_paired_hit(source: Node2D, attack: AttackData) -> bool:
	return _delivering_hit and source == player and attack in [knee_attack, throw_attack]


func _deliver(attack: AttackData) -> void:
	_delivering_hit = true
	var landed := victim.hurtbox.receive_attack(attack, Vector2.ZERO, player)
	_delivering_hit = false
	if landed:
		player.audio_component.play_attack_hit(attack)


func release() -> void:
	if not is_active():
		return
	var released := victim
	var interrupted_flight := phase == THROW and frame > 8 and frame <= THROW_LANDING_FRAME
	victim = null
	phase = INACTIVE
	frame = 0
	if is_instance_valid(released):
		if released.tree_exiting.is_connected(release):
			released.tree_exiting.disconnect(release)
		if is_instance_valid(player):
			player.remove_collision_exception_with(released)
			released.remove_collision_exception_with(player)
		released.visuals.position = _victim_visual_position
		# An interrupted nonlethal throw snaps back to the ground here. Lethal
		# interruptions instead play the ordinary death fall and its landing.
		if (
			interrupted_flight and not released.health_component.is_dead()
			and not released.hit_reaction_component.is_knocked_down()
		):
			released.hit_reaction_component.report_ground_landing()
		released.release_hair_grab(self)
	grab_finished.emit()


func sync_visuals() -> void:
	if not is_active() or not is_instance_valid(victim):
		return
	var billy_animation: StringName = &"hair_grab"
	var billy_pose: int = 3 if frame >= ENTRY_FRAMES else mini(frame / 4, 1)
	var enemy_animation: StringName = &"grabbed"
	var enemy_pose: int = 0
	if phase == KNEE:
		billy_animation = &"knee"
		billy_pose = 0 if frame < 12 else 1
		if frame >= KNEE_HIT_FRAME and frame < 12:
			enemy_pose = 1 if frame < 8 else 2
	elif phase == THROW:
		billy_animation = &"hair_throw"
		billy_pose = mini(frame / 8, 3)
		enemy_animation = &"thrown"
		enemy_pose = PoseSchedule.pose_index(frame, PackedInt32Array([0, 6, 12, 18, 26, 32]), 6)
	player.visuals.sync_grab_pose(billy_animation, billy_pose, facing)
	victim.visuals.sync_scheduled_pose(enemy_animation, enemy_pose, PackedInt32Array([0, 1, 2, 3, 4, 5]), -facing)
