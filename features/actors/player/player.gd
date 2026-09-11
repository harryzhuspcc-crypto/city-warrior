class_name Player
extends CharacterBody2D

@export var fighter_stats: FighterStats
@export var health_component: HealthComponent
@export var movement_component: MovementComponent
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

	health_component.died.connect(_on_died)
	combat_component.attack_started.connect(_on_attack_started)
	combat_component.attack_finished.connect(_on_attack_finished)
	visuals.sync(state_machine.current_state, Vector2.RIGHT)


func _physics_process(_delta: float) -> void:
	input_component.physics_tick()
	combat_component.physics_tick()

	if health_component.is_dead():
		movement_component.stop()
		visuals.sync(state_machine.current_state, Vector2.ZERO)
		return

	if combat_component.is_attacking:
		movement_component.stop()
	elif input_component.consume_attack():
		combat_component.try_start_attack()
		movement_component.stop()
	else:
		movement_component.move(input_component.movement_direction)
		var locomotion_state := PlayerStateMachine.IDLE
		if not input_component.movement_direction.is_zero_approx():
			locomotion_state = PlayerStateMachine.MOVE
		state_machine.transition_to(locomotion_state)

	visuals.sync(state_machine.current_state, input_component.movement_direction)


func _validate_dependencies() -> void:
	assert(fighter_stats != null, "Player requires FighterStats")
	assert(health_component != null, "Player requires HealthComponent")
	assert(movement_component != null, "Player requires MovementComponent")
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

