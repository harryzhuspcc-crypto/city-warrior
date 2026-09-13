class_name PlayerStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const IDLE: StringName = &"idle"
const MOVE: StringName = &"move"
const ATTACK: StringName = &"attack"
const HITSTUN: StringName = &"hurt"
const KNOCKDOWN: StringName = &"knockdown"
const DEAD: StringName = &"death"
const CLIMB: StringName = &"climb"
const GRAB: StringName = &"grab"
const THROWN: StringName = &"being_thrown"

const VALID_STATES: Array[StringName] = [
	IDLE,
	MOVE,
	ATTACK,
	HITSTUN,
	KNOCKDOWN,
	DEAD,
	CLIMB,
	GRAB,
	THROWN,
]

var current_state: StringName = IDLE


func transition_to(next_state: StringName) -> void:
	assert(next_state in VALID_STATES, "Unknown player state: %s" % next_state)
	if next_state == current_state:
		return

	var previous_state := current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)

