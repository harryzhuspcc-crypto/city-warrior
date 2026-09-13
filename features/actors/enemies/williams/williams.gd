class_name Williams
extends CharacterBody2D

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

var _runtime_stats: FighterStats
var _has_reported_defeat: bool = false


func _ready() -> void:
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
	if not combat_component.is_attacking:
		combat_component.set_facing(ai_component.facing)

	if combat_component.is_attacking:
		movement_component.stop()
		combat_component.physics_tick()
	elif ai_component.consume_attack_request() and combat_component.try_start_attack():
		# Frame zero of the punch begins on this interval, exactly like the
		# player's activated attacks.
		movement_component.stop()
		combat_component.physics_tick()
	else:
		movement_component.move(ai_component.movement_direction)
		if ai_component.intent == EnemyAIComponent.RETREAT and is_on_wall():
			ai_component.end_retreat()
		_apply_locomotion_state()
	_sync_visuals()


func _acquire_target() -> void:
	if ai_component.has_target():
		return
	if target == null and acquire_player_target:
		target = get_tree().get_first_node_in_group(&"player") as Node2D
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


func _on_attack_started() -> void:
	state_machine.transition_to(EnemyStateMachine.ATTACK)


func _on_attack_finished(_completed_attack: AttackData, completed_naturally: bool) -> void:
	if health_component.is_dead() or hit_reaction_component.is_incapacitated():
		return
	state_machine.transition_to(EnemyStateMachine.IDLE)
	if completed_naturally:
		ai_component.notify_attack_finished()


func _on_hit_received(attack_data: AttackData, knockback: Vector2, _source: Node2D) -> void:
	# Start the reaction before cancelling so the interrupted attack finishes
	# straight into HITSTUN with no intermediate locomotion state.
	ai_component.notify_hit()
	hit_reaction_component.apply_hit(attack_data, knockback, health_component.is_dead())
	combat_component.cancel_attack()


func _on_reaction_started(reaction: StringName, _attack_data: AttackData) -> void:
	if reaction == HitReactionComponent.HITSTUN:
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
	combat_component.cancel_attack()
	state_machine.transition_to(EnemyStateMachine.DEAD)
	# A fallen enemy no longer blocks other actors but still respects walls.
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 1)
