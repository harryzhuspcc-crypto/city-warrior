class_name EnemyStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const IDLE: StringName = &"idle"
const APPROACH: StringName = &"approach"
const RETREAT: StringName = &"retreat"
const ATTACK: StringName = &"attack"
const HITSTUN: StringName = &"hurt"
const STATUS1: StringName = &"status1"
const STATUS2: StringName = &"status2"
const GRABBED: StringName = &"grabbed"
const KNOCKDOWN: StringName = &"knockdown"
const DEAD: StringName = &"death"

const VALID_STATES: Array[StringName] = [
	IDLE,
	APPROACH,
	RETREAT,
	ATTACK,
	HITSTUN,
	STATUS1,
	STATUS2,
	GRABBED,
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
