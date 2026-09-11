class_name Player
extends CharacterBody2D

@export var fighter_stats: FighterStats
@export var kick_attack_data: AttackData
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
	visuals.sync(state_machine.current_state, Vector2.RIGHT)


func _physics_process(_delta: float) -> void:
	input_component.physics_tick()
	combat_component.set_facing(input_component.movement_direction.x)
	combat_component.physics_tick()

	if health_component.is_dead():
		movement_component.stop()
		jump_component.land_immediately()
		input_component.clear_buffered_actions()
		visuals.sync(state_machine.current_state, Vector2.ZERO)
		input_component.end_physics_tick()
		return

	jump_component.physics_tick(_delta)
	if (
		not combat_component.is_attacking
		and not jump_component.is_airborne
		and input_component.consume_jump()
	):
		jump_component.try_jump()

	if combat_component.is_attacking:
		movement_component.stop()
	elif jump_component.is_airborne:
		movement_component.move(input_component.movement_direction)
		var airborne_locomotion_state := PlayerStateMachine.IDLE
		if not input_component.movement_direction.is_zero_approx():
			airborne_locomotion_state = PlayerStateMachine.MOVE
		state_machine.transition_to(airborne_locomotion_state)
	elif input_component.consume_attack():
		combat_component.try_start_attack()
		movement_component.stop()
	elif input_component.consume_kick():
		combat_component.try_start_attack(kick_attack_data)
		movement_component.stop()
	else:
		movement_component.move(input_component.movement_direction)
		var locomotion_state := PlayerStateMachine.IDLE
		if not input_component.movement_direction.is_zero_approx():
			locomotion_state = PlayerStateMachine.MOVE
		state_machine.transition_to(locomotion_state)

	jump_component.sync_ground_position()
	var visual_direction := input_component.movement_direction
	var attack_animation: StringName = &"punch"
	var attack_frame: int = 0
	var attack_startup_frames: int = 0
	if combat_component.is_attacking:
		visual_direction = Vector2(combat_component.attack_facing, 0.0)
		attack_animation = combat_component.current_attack_data.animation_name
		attack_frame = combat_component.attack_frame
		attack_startup_frames = combat_component.current_attack_data.startup_frames
	visuals.sync(
		state_machine.current_state,
		visual_direction,
		jump_component.is_airborne,
		jump_component.jump_velocity,
		attack_animation,
		attack_frame,
		attack_startup_frames
	)
	input_component.end_physics_tick()


func _validate_dependencies() -> void:
	assert(fighter_stats != null, "Player requires FighterStats")
	assert(kick_attack_data != null, "Player requires kick AttackData")
	assert(health_component != null, "Player requires HealthComponent")
	assert(movement_component != null, "Player requires MovementComponent")
	assert(jump_component != null, "Player requires JumpComponent")
	assert(combat_component != null, "Player requires CombatComponent")
	assert(input_component != null, "Player requires PlayerInputComponent")
	assert(state_machine != null, "Player requires PlayerStateMachine")
	assert(visuals != null, "Player requires PlayerVisuals")


func _on_attack_started() -> void:
	state_machine.transition_to(PlayerStateMachine.ATTACK)


func _on_attack_finished() -> void:
	var next_state := PlayerStateMachine.IDLE
	if not input_component.movement_direction.is_zero_approx():
		next_state = PlayerStateMachine.MOVE
	state_machine.transition_to(next_state)


func _on_died() -> void:
	combat_component.cancel_attack()
	state_machine.transition_to(PlayerStateMachine.DEAD)
