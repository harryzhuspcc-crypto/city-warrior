class_name EnemyStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const IDLE: StringName = &"idle"
const APPROACH: StringName = &"approach"
const RETREAT: StringName = &"retreat"
const ATTACK: StringName = &"attack"
const HITSTUN: StringName = &"hurt"
const KNOCKDOWN: StringName = &"knockdown"
const DEAD: StringName = &"death"

const VALID_STATES: Array[StringName] = [
	IDLE,
	APPROACH,
	RETREAT,
	ATTACK,
	HITSTUN,
	KNOCKDOWN,
	DEAD,
]

var current_state: StringName = IDLE


func transition_to(next_state: StringName) -> void:
	assert(next_state in VALID_STATES, "Unknown enemy state: %s" % next_state)
	if next_state == current_state:
		return

	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)
