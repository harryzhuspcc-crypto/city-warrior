class_name EncounterController
extends Node2D
## Runs one belt-scroller encounter: when the player reaches lock_x the
## camera locks, enemies spawn from the markers in turn, and the camera
## unlocks once every spawned enemy is gone.

signal encounter_started
signal enemy_spawned(enemy: Node2D)
signal enemy_defeated(remaining: int)
signal encounter_cleared

const IDLE: StringName = &"idle"
const ACTIVE: StringName = &"active"
const CLEARED: StringName = &"cleared"

## Scene root must be a Node2D offering set_target(Node2D) and a defeated
## signal; the contract is checked once when the controller is ready.
@export var enemy_scene: PackedScene
@export var actors: Node2D
## Optional is_dead() on the player stops reinforcements once nobody is
## left to fight, and optional is_elevated() holds the trigger while the
## player is above the ground plane.
@export var player: Node2D
@export var camera: BeltScrollCamera
## Marker2D children are used round-robin, so alternate sides of the view.
@export var spawn_points: Node2D
## Optional earlier encounter. This encounter cannot arm until that arena has
## cleared, preventing teleports or elevated movement from starting several
## camera locks at once.
@export var prerequisite: EncounterController
@export_range(1, 12, 1) var enemy_count: int = 3
## The encounter starts when the player reaches this x; the camera locks here.
@export var lock_x: float = 640.0
@export_range(0, 300, 1) var spawn_interval_frames: int = 45
## Off lets a level be played through without the fight: the encounter never
## arms and does not gate the level's exit.
@export var enabled: bool = true

var state: StringName = IDLE
var spawned_count: int = 0
var alive_count: int = 0
var _spawn_countdown: int = 0
var _pending_enemy_ids: Dictionary[int, bool] = {}


func _ready() -> void:
	assert(enemy_scene != null, "EncounterController requires an enemy scene")
	assert(actors != null, "EncounterController requires the Actors container")
	assert(player != null, "EncounterController requires the player")
	assert(camera != null, "EncounterController requires the belt camera")
	assert(
		spawn_points != null and spawn_points.get_child_count() > 0,
		"EncounterController requires at least one spawn marker"
	)
	_validate_enemy_contract()


func _physics_process(_delta: float) -> void:
	if state == IDLE:
		# Crossing the trigger along a ledge passes over the arena rather than
		# into it, and the fight would only drop the player off the ledge to
		# start. It arms once the player is back on the ground plane.
		if (
			enabled
			and _prerequisite_is_cleared()
			and player.global_position.x >= lock_x
			and not _player_is_elevated()
		):
			_start()
	if state != ACTIVE or spawned_count >= enemy_count:
		return
	if _player_is_dead():
		# Nobody is left to fight; reinforcements would only idle off screen.
		return
	if _spawn_countdown > 0:
		_spawn_countdown -= 1
		return
	_spawn_next()
	_spawn_countdown = spawn_interval_frames


func is_cleared() -> bool:
	return state == CLEARED or (state == IDLE and not enabled)


func _start() -> void:
	state = ACTIVE
	_spawn_countdown = 0
	camera.lock_at(lock_x)
	encounter_started.emit()


func _spawn_next() -> void:
	var enemy := enemy_scene.instantiate() as Node2D
	var marker_index := spawned_count % spawn_points.get_child_count()
	var marker := spawn_points.get_child(marker_index) as Node2D
	assert(marker != null, "Spawn markers must be Node2D")
	enemy.position = actors.to_local(marker.global_position)
	enemy.call(&"set_target", player)
	# A defeated enemy frees itself afterwards, so both signals arrive; the
	# id set counts each enemy down exactly once, and an enemy removed by
	# anything else (a hazard, a despawn) still counts instead of locking
	# the camera forever.
	var enemy_id := enemy.get_instance_id()
	_pending_enemy_ids[enemy_id] = true
	enemy.connect(&"defeated", _on_enemy_gone.bind(enemy_id))
	enemy.tree_exiting.connect(_on_enemy_gone.bind(enemy_id))
	spawned_count += 1
	alive_count += 1
	actors.add_child(enemy)
	enemy_spawned.emit(enemy)


func _on_enemy_gone(enemy_id: int) -> void:
	if not _pending_enemy_ids.erase(enemy_id):
		return
	if not is_inside_tree():
		# The whole level is leaving the tree; nothing to clear.
		return
	alive_count = maxi(alive_count - 1, 0)
	enemy_defeated.emit(alive_count)
	if state == ACTIVE and spawned_count >= enemy_count and alive_count == 0:
		state = CLEARED
		camera.unlock()
		encounter_cleared.emit()


func _player_is_dead() -> bool:
	return player.has_method(&"is_dead") and bool(player.call(&"is_dead"))


func _player_is_elevated() -> bool:
	return player.has_method(&"is_elevated") and bool(player.call(&"is_elevated"))


func _prerequisite_is_cleared() -> bool:
	return prerequisite == null or prerequisite.is_cleared()


func _validate_enemy_contract() -> void:
	var probe: Node = enemy_scene.instantiate()
	var valid := (
		probe is Node2D
		and probe.has_method(&"set_target")
		and probe.has_signal(&"defeated")
	)
	probe.free()
	assert(valid, "Encounter enemies must be Node2D scenes with set_target() and a defeated signal")
