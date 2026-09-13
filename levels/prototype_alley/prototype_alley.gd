class_name PrototypeAlley
extends Node2D
## Level orchestrator: wires the HUD to Billy's health, finishes the stage at
## the exit once the encounter is cleared, and offers a restart after defeat.

signal stage_cleared
signal player_defeated
signal restart_requested

const PLAYING: StringName = &"playing"
const CLEARED: StringName = &"cleared"
const DEFEATED: StringName = &"defeated"
const RESTART_ACTION: StringName = &"attack"

@export var actors: Node2D
@export var player: Player
@export var camera: BeltScrollCamera
@export var encounter_controller: EncounterController
@export var hud: Hud
@export var exit: Marker2D
## Closed while the encounter runs so the fight cannot be sat out on an
## invulnerable rung.
@export var ladders: Node2D
## The stage's own track, playing from the moment the level loads. Its volume
## is set in the scene: -6 dB is a starting level for music with nothing yet
## to balance against, and the first sound effect is what will really set it.
@export var music: MusicPlayer
## Frames Billy stays down before the game-over prompt appears.
@export_range(0, 600, 1) var defeat_delay_frames: int = 90
## Frames the clear banner shows before the restart prompt joins it.
@export_range(0, 600, 1) var clear_prompt_delay_frames: int = 60
@export var stage_clear_message: String = "STAGE CLEAR"
@export var restart_prompt: String = "PRESS J TO RESTART"
@export var game_over_message: String = "GAME OVER"

var state: StringName = PLAYING
var _prompt_countdown: int = 0
var _prompt_message: String = ""
var _restart_armed: bool = false


func _ready() -> void:
	_validate_dependencies()
	var health := player.health_component
	hud.set_health(health.current_health, health.maximum_health())
	health.health_changed.connect(hud.set_health)
	health.died.connect(_on_player_died)
	encounter_controller.encounter_started.connect(_on_encounter_started)
	encounter_controller.encounter_cleared.connect(_on_encounter_cleared)


func _physics_process(_delta: float) -> void:
	if state == PLAYING:
		if (
			encounter_controller.is_cleared()
			and player.global_position.x >= exit.global_position.x
		):
			_finish_stage()
		return
	if _prompt_countdown > 0:
		_prompt_countdown -= 1
		if _prompt_countdown == 0:
			_arm_restart()
		return
	if _restart_armed and Input.is_action_just_pressed(RESTART_ACTION):
		request_restart()


## Emits restart_requested, then reloads the scene when it is the running one.
func request_restart() -> void:
	restart_requested.emit()
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


func _on_encounter_started() -> void:
	_set_ladders_climbable(false)
	player.climb_component.release()


func _on_encounter_cleared() -> void:
	_set_ladders_climbable(true)


func _set_ladders_climbable(climbable: bool) -> void:
	if ladders == null:
		return
	for child: Node in ladders.get_children():
		var ladder := child as Ladder
		if ladder != null:
			ladder.set_climbable(climbable)


func _finish_stage() -> void:
	state = CLEARED
	hud.show_message(stage_clear_message)
	_prompt_message = "%s\n%s" % [stage_clear_message, restart_prompt]
	_schedule_prompt(clear_prompt_delay_frames)
	stage_cleared.emit()


func _on_player_died() -> void:
	if state != PLAYING:
		return
	state = DEFEATED
	_prompt_message = "%s\n%s" % [game_over_message, restart_prompt]
	_schedule_prompt(defeat_delay_frames)
	player_defeated.emit()


func _schedule_prompt(delay_frames: int) -> void:
	_prompt_countdown = delay_frames
	if delay_frames == 0:
		_arm_restart()


func _arm_restart() -> void:
	hud.show_message(_prompt_message)
	_restart_armed = true


func _validate_dependencies() -> void:
	assert(actors != null, "PrototypeAlley requires an Actors container")
	assert(actors.y_sort_enabled, "PrototypeAlley Actors must enable Y sorting")
	assert(player != null, "PrototypeAlley requires the Player")
	assert(camera != null, "PrototypeAlley requires the BeltScrollCamera")
	assert(encounter_controller != null, "PrototypeAlley requires the EncounterController")
	assert(hud != null, "PrototypeAlley requires the Hud")
	assert(exit != null, "PrototypeAlley requires the Exit marker")
	assert(ladders != null, "PrototypeAlley requires the Ladders container")
	assert(music != null, "PrototypeAlley requires the Music player")
