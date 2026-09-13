class_name Player
extends CharacterBody2D

@export var fighter_stats: FighterStats
@export var kick_attack_data: AttackData
## The chain steps Billy earns by connecting: the cross follows the punch and
## the uppercut finishes it, while the kick chain opens twice with the basic
## kick before the turning finisher.
@export var punch_cross_attack_data: AttackData
@export var uppercut_attack_data: AttackData
@export var turn_kick_attack_data: AttackData
@export var elbow_attack_data: AttackData
@export var head_attack_data: AttackData
@export var back_kick_attack_data: AttackData
@export var jump_kick_attack_data: AttackData
@export var health_component: HealthComponent
@export var movement_component: MovementComponent
@export var jump_component: JumpComponent
@export var combat_component: CombatComponent
@export var hurtbox: HurtboxComponent
@export var hit_reaction_component: HitReactionComponent
@export var climb_component: ClimbComponent
@export var attack_chain_component: AttackChainComponent
@export var input_component: PlayerInputComponent
@export var state_machine: PlayerStateMachine
@export var visuals: PlayerVisuals
@export var audio_component: ActorAudioComponent
@export var hair_grab_component: HairGrabComponent

## Billy's combo chains, in the order their steps are earned. Each step is a
## whole attack, so the chain decides which move a press starts and combat
## still knows nothing about chains.
var punch_chain: Array[AttackData] = []
var kick_chain: Array[AttackData] = []

var _runtime_stats: FighterStats


func _ready() -> void:
	_validate_dependencies()
	_runtime_stats = fighter_stats.duplicate(true) as FighterStats
	health_component.configure(_runtime_stats)
	movement_component.configure(_runtime_stats)
	jump_component.configure(_runtime_stats)
	hit_reaction_component.configure(_runtime_stats)
	climb_component.configure(_runtime_stats)
	attack_chain_component.configure(_runtime_stats)
	punch_chain = [
		combat_component.attack_data,
		punch_cross_attack_data,
		uppercut_attack_data,
	]
	# The sheet authors one basic kick, so both openers use it.
	kick_chain = [kick_attack_data, kick_attack_data, turn_kick_attack_data]
	add_to_group(&"player")

	hair_grab_component.grab_started.connect(_on_grab_started)
	hair_grab_component.grab_finished.connect(_on_grab_finished)
	health_component.died.connect(_on_died)
	combat_component.attack_started.connect(_on_attack_started)
	combat_component.hit_landed.connect(_on_hit_landed)
	combat_component.attack_finished.connect(_on_attack_finished)
	combat_component.facing_changed.connect(_on_combat_facing_changed)
	hurtbox.hit_received.connect(_on_hit_received)
	hit_reaction_component.reaction_started.connect(_on_reaction_started)
	hit_reaction_component.recovered.connect(_on_recovered)
	climb_component.climb_started.connect(_on_climb_started)
	climb_component.climb_finished.connect(_on_climb_finished)
	climb_component.platform_entered.connect(_on_platform_entered)
	visuals.sync(state_machine.current_state, Vector2.RIGHT)


func _physics_process(delta: float) -> void:
	input_component.physics_tick()
	# The chain's window is open between attacks, so it counts down in every
	# state: a combo left hanging while Billy walks away expires on its own.
	attack_chain_component.physics_tick()
	if not hit_reaction_component.is_incapacitated() and not hair_grab_component.is_active():
		combat_component.set_facing(input_component.movement_direction.x)

	var reaction_ticked := false
	if health_component.is_dead():
		if hit_reaction_component.current_reaction != HitReactionComponent.DEATH:
			hit_reaction_component.begin_death()
		jump_component.land_immediately()
		hit_reaction_component.physics_tick()
		input_component.clear_buffered_actions()
		_sync_visuals()
		input_component.end_physics_tick()
		return

	if hit_reaction_component.is_incapacitated():
		# Hitstun and knockdown own movement (knockback slide) and block every
		# command until the reaction recovers. Buffered inputs decay normally.
		jump_component.land_immediately()
		hit_reaction_component.physics_tick()
		reaction_ticked = true
		if hit_reaction_component.is_incapacitated():
			jump_component.sync_ground_position()
			_sync_visuals()
			input_component.end_physics_tick()
			return
		# Recovered on this tick: fall through so locomotion resumes now
		# instead of rendering MOVE for one motionless frame.

	if not reaction_ticked:
		# Nothing to react to, but the consecutive-hit chain still decays.
		hit_reaction_component.physics_tick()

	if hair_grab_component.is_active():
		hair_grab_component.physics_tick()
		jump_component.sync_ground_position()
		_sync_visuals()
		input_component.end_physics_tick()
		return

	if climb_component.is_elevated():
		if _process_elevated(delta):
			return
		# Back on the ground plane this tick: fall through so locomotion
		# resumes now.
	elif _can_grab_ladder() and climb_component.try_grab():
		_process_elevated(delta)
		return

	jump_component.physics_tick(delta)
	var attack_existed_at_tick_start := combat_component.is_attacking
	if attack_existed_at_tick_start:
		_process_existing_attack()
	else:
		var action_started := _try_start_buffered_action()
		if combat_component.is_attacking:
			_process_activated_attack()
		elif not action_started or jump_component.is_airborne:
			_apply_locomotion()

	jump_component.sync_ground_position()
	_sync_visuals()
	input_component.end_physics_tick()


## Ticks a Billy who is off the ground plane. The ladder and the ledge hand
## over to each other — the top rung is the ledge's surface — so both are
## ticked here rather than in separate branches: the jump owns the visual
## height whenever this returns, and a top step that ended the climb without
## ending the elevation must not let it reset Billy to the ground. Returns
## false once he is back on the ground plane.
func _process_elevated(delta: float) -> bool:
	if climb_component.is_climbing:
		_tick_climb(delta)
	if climb_component.is_on_platform:
		_tick_ledge()
	if not climb_component.is_elevated():
		return false
	jump_component.sync_ground_position()
	_sync_visuals()
	input_component.end_physics_tick()
	return true


## Climbs the ladder. Attack, kick, and jump presses are dropped on the ladder
## rather than buffered for the dismount.
func _tick_climb(delta: float) -> void:
	movement_component.stop()
	input_component.clear_buffered_actions()
	climb_component.physics_tick(input_component.movement_direction, delta)


## Stands on a ledge. Billy keeps the ladder's rules — no attack, kick, or
## jump — but walks the surface: a ledge is one depth line, so only x moves,
## and the ledge's own span stops him at either end.
func _tick_ledge() -> void:
	input_component.clear_buffered_actions()
	if climb_component.platform_tick(input_component.movement_direction):
		# Back on a rung: the climb owns him from the next tick.
		movement_component.stop()
		return
	if not climb_component.is_on_platform:
		return
	_walk(Vector2(input_component.movement_direction.x, 0.0))
	climb_component.hold_on_platform()


func _can_grab_ladder() -> bool:
	return (
		not jump_component.is_airborne
		and not combat_component.is_attacking
		and input_component.movement_direction.y < 0.0
	)


func _try_start_buffered_action() -> bool:
	if jump_component.is_airborne:
		if input_component.consume_back_kick_chord() or input_component.consume_kick():
			return _start_attack(jump_kick_attack_data)
		return false

	if input_component.consume_elbow_chord():
		return _start_attack(elbow_attack_data)
	if input_component.consume_back_kick_chord():
		return _start_attack(back_kick_attack_data)

	var head_direction := input_component.consume_head_attack_direction()
	if not is_zero_approx(head_direction):
		combat_component.set_facing(head_direction)
		return _start_attack(head_attack_data)

	if input_component.consume_ready_jump():
		return jump_component.try_jump()
	if input_component.consume_ready_attack():
		return _start_chain_attack(punch_chain)
	if input_component.consume_ready_kick():
		return _start_chain_attack(kick_chain)
	return false


## Starts the chain's current step. A step that cannot start breaks the chain
## rather than leaving it waiting on an attack that never ran.
func _start_chain_attack(chain: Array[AttackData]) -> bool:
	if _start_attack(attack_chain_component.next_attack(chain)):
		return true
	attack_chain_component.reset()
	return false


func _start_attack(selected_attack: AttackData = null) -> bool:
	var started := combat_component.try_start_attack(selected_attack)
	if not started:
		return false
	var latched_attack := combat_component.current_attack_data
	if (
		latched_attack.starts_jump
		and not jump_component.try_jump(latched_attack.jump_height_scale)
	):
		combat_component.cancel_attack()
		return false
	return true


func _process_existing_attack() -> void:
	var attack := combat_component.current_attack_data
	var finishes_from_recovery := (
		combat_component.current_phase == CombatComponent.RECOVERY
		and combat_component.attack_frame == attack.total_frames() - 1
	)
	var finishes_from_landing := attack.finishes_on_landing and not jump_component.is_airborne
	if not finishes_from_recovery and not finishes_from_landing:
		_apply_attack_movement()
		combat_component.physics_tick(jump_component.is_airborne)
		return

	# Recovery is already complete when this interval begins. Finish before
	# selecting movement so MOVE state never renders for a zero-motion hitch.
	combat_component.physics_tick(jump_component.is_airborne)
	var action_started := _try_start_buffered_action()
	if combat_component.is_attacking:
		_process_activated_attack()
	elif not action_started or jump_component.is_airborne:
		_apply_locomotion()
	else:
		movement_component.stop()


func _process_activated_attack() -> void:
	# The command starts attack frame zero on this physics interval. Apply its
	# movement first, then resolve/advance combat so frame-zero motion is not
	# delayed or repeated on the following tick.
	_apply_attack_movement()
	combat_component.physics_tick(jump_component.is_airborne)


func _apply_attack_movement() -> void:
	var attack := combat_component.current_attack_data
	if attack == null:
		movement_component.stop()
		return
	if attack.movement_is_active(combat_component.attack_frame):
		movement_component.move_at_speed(
			Vector2(combat_component.attack_facing, 0.0),
			attack.movement_speed
		)
		return
	if attack.allow_air_movement and jump_component.is_airborne:
		movement_component.move(input_component.movement_direction)
		return
	movement_component.stop()


func _apply_locomotion() -> void:
	_walk(input_component.movement_direction)
	hair_grab_component.try_contact(input_component.movement_direction)


## Walks in one direction and presents the matching locomotion state.
func _walk(direction: Vector2) -> void:
	movement_component.move(direction)
	var locomotion_state := PlayerStateMachine.IDLE
	if not direction.is_zero_approx():
		locomotion_state = PlayerStateMachine.MOVE
	state_machine.transition_to(locomotion_state)


func _sync_visuals() -> void:
	if hair_grab_component.is_active():
		hair_grab_component.sync_visuals()
		return
	var visual_direction := input_component.movement_direction
	var attack_animation: StringName = &"punch"
	var attack_frame: int = 0
	var attack_frame_starts := PackedInt32Array([0])
	var attack_animation_facing_multiplier: int = 1
	if combat_component.is_attacking and not hit_reaction_component.is_incapacitated():
		var attack := combat_component.current_attack_data
		visual_direction = Vector2(combat_component.attack_facing, 0.0)
		attack_animation = attack.animation_name
		attack_frame = combat_component.attack_frame
		attack_frame_starts = attack.animation_frame_starts
		attack_animation_facing_multiplier = attack.animation_facing_multiplier
	elif (
		hit_reaction_component.is_incapacitated()
		or health_component.is_dead()
		or climb_component.is_climbing
	):
		visual_direction = Vector2.ZERO
	visuals.sync(
		state_machine.current_state,
		visual_direction,
		jump_component.is_airborne,
		jump_component.jump_velocity,
		attack_animation,
		attack_frame,
		attack_frame_starts,
		attack_animation_facing_multiplier,
		hit_reaction_component.reaction_frame,
		_reaction_pose_starts(),
		climb_component.pose_index(visuals.climb_pose_count())
	)


func _reaction_pose_starts() -> PackedInt32Array:
	var reaction := hit_reaction_component.current_reaction
	if reaction == HitReactionComponent.KNOCKDOWN:
		return _runtime_stats.knockdown_pose_starts
	if reaction == HitReactionComponent.DEATH:
		return _runtime_stats.death_pose_starts
	return _runtime_stats.hurt_pose_starts


func _validate_dependencies() -> void:
	assert(fighter_stats != null, "Player requires FighterStats")
	assert(kick_attack_data != null, "Player requires kick AttackData")
	assert(punch_cross_attack_data != null, "Player requires cross-punch AttackData")
	assert(uppercut_attack_data != null, "Player requires uppercut AttackData")
	assert(turn_kick_attack_data != null, "Player requires turning-kick AttackData")
	assert(elbow_attack_data != null, "Player requires elbow AttackData")
	assert(head_attack_data != null, "Player requires head-attack AttackData")
	assert(back_kick_attack_data != null, "Player requires back-kick AttackData")
	assert(jump_kick_attack_data != null, "Player requires jump-kick AttackData")
	assert(health_component != null, "Player requires HealthComponent")
	assert(movement_component != null, "Player requires MovementComponent")
	assert(jump_component != null, "Player requires JumpComponent")
	assert(combat_component != null, "Player requires CombatComponent")
	assert(hurtbox != null, "Player requires HurtboxComponent")
	assert(hit_reaction_component != null, "Player requires HitReactionComponent")
	assert(climb_component != null, "Player requires ClimbComponent")
	assert(attack_chain_component != null, "Player requires AttackChainComponent")
	assert(input_component != null, "Player requires PlayerInputComponent")
	assert(state_machine != null, "Player requires PlayerStateMachine")
	assert(visuals != null, "Player requires PlayerVisuals")
	assert(audio_component != null, "Player requires ActorAudioComponent")
	assert(hair_grab_component != null, "Player requires HairGrabComponent")


func _on_attack_started() -> void:
	hair_grab_component.release()
	state_machine.transition_to(PlayerStateMachine.ATTACK)


func _on_attack_finished(completed_attack: AttackData, completed_naturally: bool) -> void:
	# The chain is told first: an attack interrupted by a hit, or one that ends
	# while Billy is already down, still has to break the combo.
	attack_chain_component.finish_attack(completed_attack, completed_naturally)
	if health_component.is_dead() or hit_reaction_component.is_incapacitated():
		return
	_transition_to_locomotion_state()


func _transition_to_locomotion_state() -> void:
	var next_state := PlayerStateMachine.IDLE
	if not input_component.movement_direction.is_zero_approx():
		next_state = PlayerStateMachine.MOVE
	state_machine.transition_to(next_state)


## Only a hit that Billy's own chain step landed earns the next step.
func _on_hit_landed(
	_target: HurtboxComponent,
	attack_data: AttackData,
	_knockback: Vector2
) -> void:
	attack_chain_component.confirm_hit(attack_data)


func _on_hit_received(attack_data: AttackData, knockback: Vector2, _source: Node2D) -> void:
	# Airborne hits always floor Billy: the jump is visual height only, so the
	# body is already on the ground plane and can start its knockdown slide.
	var was_airborne := jump_component.is_airborne
	if was_airborne:
		jump_component.land_immediately()
	# Start the reaction before cancelling so an interrupted attack finishes
	# straight into the reaction state with no intermediate locomotion state.
	hit_reaction_component.apply_hit(
		attack_data,
		knockback,
		health_component.is_dead(),
		was_airborne
	)
	combat_component.cancel_attack()


func can_hair_grab() -> bool:
	return (
		is_inside_tree() and not is_queued_for_deletion()
		and not is_dead() and not hit_reaction_component.is_incapacitated()
		and not combat_component.is_attacking and not jump_component.is_airborne
		and not climb_component.is_elevated() and not hair_grab_component.is_active()
	)


func _on_grab_started() -> void:
	state_machine.transition_to(PlayerStateMachine.GRAB)


func _on_grab_finished() -> void:
	input_component.clear_buffered_actions()
	if not is_dead() and not hit_reaction_component.is_incapacitated():
		_transition_to_locomotion_state()
		_sync_visuals()


func _exit_tree() -> void:
	if is_instance_valid(hair_grab_component):
		hair_grab_component.release()


func is_dead() -> bool:
	return health_component.is_dead()


## True while Billy is off the ground plane on a rung or a ledge. Encounters
## read it so a crossing made along a ledge passes over the arena.
func is_elevated() -> bool:
	return climb_component.is_elevated()


## Pixels Billy's sprite stands above the ground plane because of a climb. The
## camera raises its band by this; a jump is deliberately left out, since the
## view must not bob on every hop.
func visual_elevation() -> float:
	return climb_component.elevation()


func _on_reaction_started(reaction: StringName, _attack_data: AttackData) -> void:
	if hit_reaction_component.is_knocked_down() and not is_zero_approx(hit_reaction_component.fall_direction):
		visuals.set_facing(-hit_reaction_component.fall_direction)
	hair_grab_component.release()
	if reaction == HitReactionComponent.HITSTUN:
		state_machine.transition_to(PlayerStateMachine.HITSTUN)
	elif reaction == HitReactionComponent.KNOCKDOWN:
		state_machine.transition_to(PlayerStateMachine.KNOCKDOWN)
	else:
		state_machine.transition_to(PlayerStateMachine.DEAD)
	# Hits land during the attacker's physics tick, which may run after this
	# actor already synced presentation. Show the reaction pose immediately.
	_sync_visuals()


func _on_recovered() -> void:
	_transition_to_locomotion_state()


func _on_combat_facing_changed(facing: float) -> void:
	visuals.set_facing(facing)


func _on_climb_started(_ladder: Ladder) -> void:
	hair_grab_component.release()
	state_machine.transition_to(PlayerStateMachine.CLIMB)


func _on_climb_finished() -> void:
	if health_component.is_dead() or hit_reaction_component.is_incapacitated():
		return
	_transition_to_locomotion_state()


## The ledge is walked, not climbed: Billy presents idle and walk poses up
## there, so the climb state ends at the top rung.
func _on_platform_entered(_platform: ClimbPlatform) -> void:
	if health_component.is_dead() or hit_reaction_component.is_incapacitated():
		return
	_transition_to_locomotion_state()


func _on_died() -> void:
	hair_grab_component.release()
	combat_component.cancel_attack()
	climb_component.release()
	state_machine.transition_to(PlayerStateMachine.DEAD)
