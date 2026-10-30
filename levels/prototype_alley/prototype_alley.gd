class_name PrototypeAlley
extends Node2D
## Shared level orchestrator for the street and industrial yard. Wires Billy
## to the HUD, gates the exit behind every fight, optionally starts a next-stage
## cinematic, and offers a current-scene restart after defeat/terminal clear.

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
## Ordered EncounterController children. Each one points at its prerequisite,
## so the opening, middle, ending, and boss arenas cannot overlap.
@export var encounters: Node2D
## The established middle encounter remains exposed for focused tests and
## tools that operate on one arena.
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
## Activation replaces the stage track on the same Music player, not a second
## overlapping player. The boss uses the final screen after the ending wave.
@export var boss_encounter: EncounterController
@export var boss_music: AudioStream
## Non-looping cue that replaces any active theme once Billy reaches the exit
## after clearing every encounter.
@export var stage_clear_music: AudioStreamPlayer
@export var stage_transition: StageTransition
@export var stage_name: String = "STAGE 1 - STREETS"
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
	hud.set_stage_name(stage_name)
	hud.set_health(health.current_health, health.maximum_health())
	health.health_changed.connect(hud.set_health)
	health.died.connect(_on_player_died)
	if stage_transition != null:
		stage_transition.transition_failed.connect(_on_transition_failed)
	for encounter: EncounterController in encounter_controllers():
		encounter.encounter_started.connect(_on_encounter_started.bind(encounter))
		encounter.encounter_cleared.connect(_on_encounter_cleared)


func _physics_process(_delta: float) -> void:
	if stage_transition != null and stage_transition.is_busy():
		return
	if state == PLAYING:
		if (
			_all_encounters_cleared()
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


func _on_encounter_started(encounter: EncounterController) -> void:
	if state == PLAYING and encounter == boss_encounter:
		music.play_track(boss_music)
	_set_ladders_climbable(false)
	player.climb_component.release()


func _on_encounter_cleared() -> void:
	for encounter: EncounterController in encounter_controllers():
		if encounter.state == EncounterController.ACTIVE:
			return
	_set_ladders_climbable(true)


func encounter_controllers() -> Array[EncounterController]:
	var result: Array[EncounterController] = []
	for child: Node in encounters.get_children():
		var encounter := child as EncounterController
		if encounter != null:
			result.append(encounter)
	return result


func set_encounters_enabled(enabled: bool) -> void:
	for encounter: EncounterController in encounter_controllers():
		encounter.enabled = enabled


func _all_encounters_cleared() -> bool:
	for encounter: EncounterController in encounter_controllers():
		if not encounter.is_cleared():
			return false
	return true


func _set_ladders_climbable(climbable: bool) -> void:
	if ladders == null:
		return
	for child: Node in ladders.get_children():
		var ladder := child as Ladder
		if ladder != null:
			ladder.set_climbable(climbable)


func _finish_stage() -> void:
	if state != PLAYING:
		return
	state = CLEARED
	music.stop()
	stage_clear_music.play()
	hud.show_message(stage_clear_message)
	if stage_transition != null and stage_transition.has_next_stage():
		stage_transition.begin_outro()
	else:
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


func _on_transition_failed(_scene_path: String) -> void:
	_prompt_message = "COULD NOT LOAD NEXT STAGE\n%s" % restart_prompt
	_schedule_prompt(0)


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
	assert(encounters != null, "PrototypeAlley requires an Encounters container")
	assert(encounter_controllers().size() > 0, "PrototypeAlley requires encounters")
	assert(encounter_controller != null, "PrototypeAlley requires the EncounterController")
	assert(hud != null, "PrototypeAlley requires the Hud")
	assert(exit != null, "PrototypeAlley requires the Exit marker")
	assert(ladders != null, "PrototypeAlley requires the Ladders container")
	assert(music != null, "PrototypeAlley requires the Music player")
	assert(boss_encounter != null, "PrototypeAlley requires the BossEncounter")
	assert(boss_music != null, "PrototypeAlley requires boss music")
	assert(stage_clear_music != null, "PrototypeAlley requires stage-clear music")
	assert(stage_clear_music.stream != null, "Stage-clear music requires an AudioStream")
