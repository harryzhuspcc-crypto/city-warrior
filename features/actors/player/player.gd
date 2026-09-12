class_name Player
extends CharacterBody2D

@export var fighter_stats: FighterStats
@export var kick_attack_data: AttackData
@export var elbow_attack_data: AttackData
@export var head_attack_data: AttackData
@export var back_kick_attack_data: AttackData
@export var jump_kick_attack_data: AttackData
@export var health_component: HealthComponent
@export var movement_component: MovementComponent
@export var jump_component: JumpComponent
@export var combat_component: CombatComponent
@export var input_component: PlayerInputComponent
@export var state_machine: PlayerStateMachine
@export var visuals: PlayerVisuals

var _runtime_stats: FighterStats


func _ready() -> void:
	_validate_dependencies()
	_runtime_stats = fighter_stats.duplicate(true) as FighterStats
	health_component.configure(_runtime_stats)
	movement_component.configure(_runtime_stats)
	jump_component.configure(_runtime_stats)

	health_component.died.connect(_on_died)
	combat_component.attack_started.connect(_on_attack_started)
	combat_component.attack_finished.connect(_on_attack_finished)
	combat_component.facing_changed.connect(_on_combat_facing_changed)
	visuals.sync(state_machine.current_state, Vector2.RIGHT)


func _physics_process(delta: float) -> void:
	input_component.physics_tick()
	combat_component.set_facing(input_component.movement_direction.x)

	if health_component.is_dead():
		movement_component.stop()
		jump_component.land_immediately()
		input_component.clear_buffered_actions()
		visuals.sync(state_machine.current_state, Vector2.ZERO)
		input_component.end_physics_tick()
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
		return _start_attack()
	if input_component.consume_ready_kick():
		return _start_attack(kick_attack_data)
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
	movement_component.move(input_component.movement_direction)
	var locomotion_state := PlayerStateMachine.IDLE
	if not input_component.movement_direction.is_zero_approx():
		locomotion_state = PlayerStateMachine.MOVE
	state_machine.transition_to(locomotion_state)


func _sync_visuals() -> void:
	var visual_direction := input_component.movement_direction
	var attack_animation: StringName = &"punch"
	var attack_frame: int = 0
	var attack_frame_starts := PackedInt32Array([0])
	var attack_animation_facing_multiplier: int = 1
	if combat_component.is_attacking:
		var attack := combat_component.current_attack_data
		visual_direction = Vector2(combat_component.attack_facing, 0.0)
		attack_animation = attack.animation_name
		attack_frame = combat_component.attack_frame
		attack_frame_starts = attack.animation_frame_starts
		attack_animation_facing_multiplier = attack.animation_facing_multiplier
	visuals.sync(
		state_machine.current_state,
		visual_direction,
		jump_component.is_airborne,
		jump_component.jump_velocity,
		attack_animation,
		attack_frame,
		attack_frame_starts,
		attack_animation_facing_multiplier
	)


func _validate_dependencies() -> void:
	assert(fighter_stats != null, "Player requires FighterStats")
	assert(kick_attack_data != null, "Player requires kick AttackData")
	assert(elbow_attack_data != null, "Player requires elbow AttackData")
	assert(head_attack_data != null, "Player requires head-attack AttackData")
	assert(back_kick_attack_data != null, "Player requires back-kick AttackData")
	assert(jump_kick_attack_data != null, "Player requires jump-kick AttackData")
	assert(health_component != null, "Player requires HealthComponent")
	assert(movement_component != null, "Player requires MovementComponent")
	assert(jump_component != null, "Player requires JumpComponent")
	assert(combat_component != null, "Player requires CombatComponent")
	assert(input_component != null, "Player requires PlayerInputComponent")
	assert(state_machine != null, "Player requires PlayerStateMachine")
	assert(visuals != null, "Player requires PlayerVisuals")


func _on_attack_started() -> void:
	state_machine.transition_to(PlayerStateMachine.ATTACK)


func _on_attack_finished(_completed_attack: AttackData, _completed_naturally: bool) -> void:
	var next_state := PlayerStateMachine.IDLE
	if not input_component.movement_direction.is_zero_approx():
		next_state = PlayerStateMachine.MOVE
	state_machine.transition_to(next_state)


func _on_combat_facing_changed(facing: float) -> void:
	visuals.set_facing(facing)


func _on_died() -> void:
	combat_component.cancel_attack()
	state_machine.transition_to(PlayerStateMachine.DEAD)
