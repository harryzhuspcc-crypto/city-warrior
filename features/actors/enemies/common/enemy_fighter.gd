class_name EnemyFighter
extends CharacterBody2D

const TerrainPursuit := preload("res://features/actors/enemies/common/enemy_terrain_pursuit.gd")

@export var can_follow_platforms: bool = false
var _terrain_pursuit: RefCounted

signal defeated

@export var fighter_stats: FighterStats
## Optional. When empty and acquire_player_target is on, the first node in
## the "player" group is targeted as soon as one exists.
@export var target: Node2D
## Turn off to keep an enemy passive when no explicit target is assigned.
@export var acquire_player_target: bool = true
@export_range(0, 600, 1) var death_linger_frames: int = 90
@export var health_component: HealthComponent
@export var movement_component: MovementComponent
@export var combat_component: CombatComponent
@export var hurtbox: HurtboxComponent
@export var hit_reaction_component: HitReactionComponent
@export var ai_component: EnemyAIComponent
@export var state_machine: EnemyStateMachine
@export var visuals: EnemyVisuals
@export var audio_component: ActorAudioComponent
## Optional paired move; ordinary enemies retain their existing punch loop.
@export var throw_component: EnemyThrowComponent

var grab_owner: HairGrabComponent
var _runtime_stats: FighterStats
var _has_reported_defeat: bool = false
var terrain_motor: BeltTerrainMotor


func _ready() -> void:
	_terrain_pursuit = TerrainPursuit.new(self)
	_validate_dependencies()
	_runtime_stats = fighter_stats.duplicate(true) as FighterStats
	health_component.configure(_runtime_stats)
	movement_component.configure(_runtime_stats)
	hit_reaction_component.configure(_runtime_stats)

	health_component.died.connect(_on_died)
	combat_component.attack_started.connect(_on_attack_started)
	combat_component.attack_finished.connect(_on_attack_finished)
	hurtbox.hit_received.connect(_on_hit_received)
	hit_reaction_component.reaction_started.connect(_on_reaction_started)
	hit_reaction_component.recovered.connect(_on_recovered)

	_acquire_target()
	combat_component.set_facing(ai_component.facing)
	_sync_visuals()


func set_target(next_target: Node2D) -> void:
	target = next_target
	ai_component.set_target(next_target)


func _physics_process(_delta: float) -> void:
	if health_component.is_dead():
		if hit_reaction_component.current_reaction != HitReactionComponent.DEATH:
			hit_reaction_component.begin_death()
		hit_reaction_component.physics_tick()
		_sync_visuals()
		if (
			not _has_reported_defeat
			and hit_reaction_component.reaction_frame >= death_linger_frames
		):
			_has_reported_defeat = true
			defeated.emit()
			queue_free()
		return

	if terrain_motor != null and terrain_motor.is_falling():
		_cancel_throw()
		combat_component.cancel_attack()
		if can_follow_platforms and not hit_reaction_component.is_incapacitated() and not is_instance_valid(grab_owner):
			var direction: Vector2 = _terrain_pursuit.direction()
			movement_component.move(direction)
			if not is_zero_approx(direction.x):
				ai_component.facing = signf(direction.x)
			# These sheets have no jump animation; hold a locomotion pose.
			visuals.sync_scheduled_pose(&"walk", 0, PackedInt32Array([0]), ai_component.facing)
		else:
			movement_component.stop()
			visuals.sync_scheduled_pose(&"knockdown", 0, PackedInt32Array([0]), ai_component.facing)
		return

	if throw_component != null and throw_component.is_active():
		throw_component.physics_tick()
		return

	if is_instance_valid(grab_owner):
		# The pair's clock/motion is ticked exactly once, by Billy.
		velocity = Vector2.ZERO
		return

	if hit_reaction_component.is_incapacitated():
		hit_reaction_component.physics_tick()
		_sync_visuals()
		return
	# Nothing to react to, but the consecutive-hit chain still decays.
	hit_reaction_component.physics_tick()

	_acquire_target()
	ai_component.physics_tick(
		global_position,
		not combat_component.is_attacking and not _target_is_dead()
	)
	if can_follow_platforms and terrain_motor != null and ai_component.has_target() and not _target_is_dead() and not combat_component.is_attacking:
		var target_height: float = target.visual_elevation() if target is Player else 0.0
		if absf(target_height - combat_elevation()) > 8.0 or global_position.distance_to(target.global_position) > 36.0:
			ai_component.consume_attack_request()
			var direction: Vector2 = _terrain_pursuit.direction()
			ai_component.movement_direction = direction
			ai_component.intent = EnemyAIComponent.APPROACH
			if not is_zero_approx(direction.x):
				ai_component.facing = signf(direction.x)
			movement_component.move(direction)
			_apply_locomotion_state()
			_sync_visuals()
			return
	if not combat_component.is_attacking:
		combat_component.set_facing(ai_component.facing)

	if combat_component.is_attacking:
		movement_component.stop()
		combat_component.physics_tick()
	elif ai_component.consume_attack_request() and _try_start_ai_attack():
		# Frame zero of the punch begins on this interval, exactly like the
		# player's activated attacks.
		movement_component.stop()
		if throw_component != null and throw_component.is_active():
			throw_component.physics_tick()
		else:
			combat_component.physics_tick()
	else:
		movement_component.move(ai_component.movement_direction)
		if ai_component.intent == EnemyAIComponent.RETREAT and is_on_wall():
			ai_component.end_retreat()
		_apply_locomotion_state()
	_sync_visuals()


func _try_start_ai_attack() -> bool:
	if throw_component != null and throw_component.try_start(target as Player):
		return true
	return combat_component.try_start_attack()


func _acquire_target() -> void:
	# A released grab may have lost Billy to removal/free rather than death.
	# Clear both caches before passing a typed reference back into the AI.
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		target = null
		ai_component.set_target(null)
	if ai_component.has_target():
		return
	if target == null and acquire_player_target:
		var candidate := get_tree().get_first_node_in_group(&"player") as Node2D
		if is_instance_valid(candidate) and not candidate.is_queued_for_deletion():
			target = candidate
	if target != null:
		ai_component.set_target(target)


func _target_is_dead() -> bool:
	return (
		ai_component.has_target()
		and target.has_method(&"is_dead")
		and target.is_dead()
	)


func _apply_locomotion_state() -> void:
	var next_state := EnemyStateMachine.IDLE
	if not ai_component.movement_direction.is_zero_approx():
		if ai_component.intent == EnemyAIComponent.RETREAT:
			next_state = EnemyStateMachine.RETREAT
		else:
			next_state = EnemyStateMachine.APPROACH
	state_machine.transition_to(next_state)


func _sync_visuals() -> void:
	if throw_component != null and throw_component.is_active():
		throw_component.sync_visuals()
		return
	var state := state_machine.current_state
	if state == EnemyStateMachine.ATTACK and combat_component.is_attacking:
		var attack := combat_component.current_attack_data
		visuals.sync_scheduled_pose(
			attack.animation_name,
			combat_component.attack_frame,
			attack.animation_frame_starts,
			combat_component.attack_facing * float(attack.animation_facing_multiplier)
		)
		return
	if state in [EnemyStateMachine.STATUS1, EnemyStateMachine.STATUS2]:
		visuals.sync_scheduled_pose(
			state,
			hit_reaction_component.reaction_frame,
			_runtime_stats.hurt_pose_starts if state == EnemyStateMachine.STATUS1 else PackedInt32Array([0]),
			ai_component.facing
		)
		return
	if state == EnemyStateMachine.HITSTUN:
		visuals.sync_scheduled_pose(
			&"hurt",
			hit_reaction_component.reaction_frame,
			_runtime_stats.hurt_pose_starts,
			ai_component.facing
		)
		return
	if state == EnemyStateMachine.KNOCKDOWN:
		visuals.sync_scheduled_pose(
			&"knockdown",
			hit_reaction_component.reaction_frame,
			_runtime_stats.knockdown_pose_starts,
			ai_component.facing
		)
		return
	if state == EnemyStateMachine.DEAD:
		visuals.sync_scheduled_pose(
			&"death",
			hit_reaction_component.reaction_frame,
			_runtime_stats.death_pose_starts,
			ai_component.facing
		)
		return
	var is_moving := (
		state == EnemyStateMachine.APPROACH
		or state == EnemyStateMachine.RETREAT
	)
	visuals.sync_locomotion(is_moving, ai_component.movement_direction, ai_component.facing)


func can_be_hair_grabbed() -> bool:
	return (
		is_inside_tree() and not is_queued_for_deletion()
		and not health_component.is_dead() and not is_instance_valid(grab_owner)
		and hit_reaction_component.current_reaction == HitReactionComponent.STATUS2
		and not hurtbox.is_invulnerable
		and (terrain_motor == null or not terrain_motor.is_falling())
	)


func combat_elevation() -> float:
	return terrain_motor.elevation() if terrain_motor != null else 0.0


func claim_hair_grab(owner_component: HairGrabComponent) -> void:
	grab_owner = owner_component
	hit_reaction_component.reset()
	combat_component.cancel_attack()
	# Preserve the pair's facing through throw landing and get-up, even if
	# Billy approached a passive enemy from behind.
	ai_component.facing = -owner_component.facing
	combat_component.set_facing(ai_component.facing)
	ai_component.notify_hit()
	velocity = Vector2.ZERO
	state_machine.transition_to(EnemyStateMachine.GRABBED)


func release_hair_grab(owner_component: HairGrabComponent) -> void:
	if grab_owner != owner_component:
		return
	grab_owner = null
	if not health_component.is_dead() and not hit_reaction_component.is_incapacitated():
		state_machine.transition_to(EnemyStateMachine.IDLE)
		ai_component.notify_recovered()
		_sync_visuals()


func finish_hair_throw(attack: AttackData) -> void:
	# The throw already showed flight/impact. Begin on the prone pose, then
	# use the existing get-up timing rather than replaying a second fall.
	hit_reaction_component.apply_hit(attack, Vector2.ZERO, false, true, true)
	_sync_visuals()


func _exit_tree() -> void:
	_cancel_throw()
	if is_instance_valid(grab_owner):
		grab_owner.release()


func _validate_dependencies() -> void:
	assert(fighter_stats != null, "Williams requires FighterStats")
	assert(health_component != null, "Williams requires HealthComponent")
	assert(movement_component != null, "Williams requires MovementComponent")
	assert(combat_component != null, "Williams requires CombatComponent")
	assert(hurtbox != null, "Williams requires HurtboxComponent")
	assert(hit_reaction_component != null, "Williams requires HitReactionComponent")
	assert(ai_component != null, "Williams requires EnemyAIComponent")
	assert(state_machine != null, "Williams requires EnemyStateMachine")
	assert(visuals != null, "Williams requires EnemyVisuals")
	assert(audio_component != null, "Williams requires ActorAudioComponent")


func _cancel_throw() -> void:
	if is_instance_valid(throw_component):
		throw_component.release()


func _on_attack_started() -> void:
	_cancel_throw()
	if is_instance_valid(grab_owner):
		grab_owner.release()
	state_machine.transition_to(EnemyStateMachine.ATTACK)


func _on_attack_finished(_completed_attack: AttackData, completed_naturally: bool) -> void:
	if health_component.is_dead() or hit_reaction_component.is_incapacitated():
		return
	state_machine.transition_to(EnemyStateMachine.IDLE)
	if completed_naturally:
		ai_component.notify_attack_finished()


func _on_hit_received(attack_data: AttackData, knockback: Vector2, source: Node2D) -> void:
	_cancel_throw()
	if is_instance_valid(grab_owner):
		if grab_owner.is_paired_hit(source, attack_data) and not health_component.is_dead():
			return
		grab_owner.release()
	# Start the reaction before cancelling so the interrupted attack finishes
	# straight into HITSTUN with no intermediate locomotion state.
	ai_component.notify_hit()
	hit_reaction_component.apply_hit(attack_data, knockback, health_component.is_dead())
	combat_component.cancel_attack()


func _on_reaction_started(reaction: StringName, _attack_data: AttackData) -> void:
	_cancel_throw()
	if hit_reaction_component.is_knocked_down() and not is_zero_approx(hit_reaction_component.fall_direction):
		ai_component.facing = -hit_reaction_component.fall_direction
	if is_instance_valid(grab_owner):
		grab_owner.release()
	if reaction in [HitReactionComponent.STATUS1, HitReactionComponent.STATUS2]:
		state_machine.transition_to(reaction)
	elif reaction == HitReactionComponent.HITSTUN:
		state_machine.transition_to(EnemyStateMachine.HITSTUN)
	elif reaction == HitReactionComponent.KNOCKDOWN:
		state_machine.transition_to(EnemyStateMachine.KNOCKDOWN)
	else:
		state_machine.transition_to(EnemyStateMachine.DEAD)
	# Hits land during the attacker's physics tick, which may run after this
	# actor already synced presentation. Show the reaction pose immediately.
	_sync_visuals()


func _on_recovered() -> void:
	state_machine.transition_to(EnemyStateMachine.IDLE)
	ai_component.notify_recovered()


func _on_died() -> void:
	_cancel_throw()
	var throw_landed := is_instance_valid(grab_owner) and grab_owner.has_landed()
	if is_instance_valid(grab_owner):
		grab_owner.release()
	if throw_landed:
		# The paired prone hold has already made ground contact. Death must
		# neither replay its fall poses nor request a second landing sound.
		hit_reaction_component.begin_death(Vector2.ZERO, null, true)
	combat_component.cancel_attack()
	state_machine.transition_to(EnemyStateMachine.DEAD)
	# A fallen enemy no longer blocks other actors but still respects walls.
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 1)
