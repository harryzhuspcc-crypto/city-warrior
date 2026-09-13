extends SceneTree

const PROTOTYPE_ALLEY_SCENE: PackedScene = preload(
	"res://levels/prototype_alley/prototype_alley.tscn"
)
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
const VIEW_WIDTH: float = 384.0
const VIEW_HEIGHT: float = 216.0
const SCREEN_EDGE_LAYER: int = 128


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Every slice gets a fresh level so camera history and encounter state
	# never leak between them.
	for slice: Callable in [
		_test_level_contract,
		_test_camera_follow,
		_test_camera_lock_rules,
		_test_encounter_flow,
		_test_exit_requires_clear,
		_test_disabled_encounter_exit,
		_test_enemies_enter_locked_view,
		_test_no_spawns_after_defeat,
		_test_hud_health,
		_test_defeat_and_restart,
		_test_live_fight_and_reload,
	]:
		var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
		root.add_child(alley)
		await physics_frame
		_isolate_middle_encounter(alley)
		var error: String = await slice.call(alley)
		if not error.is_empty():
			_fail(error)
			return
		if is_instance_valid(alley):
			root.remove_child(alley)
			alley.free()
		await physics_frame

	var multi_alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
	root.add_child(multi_alley)
	await physics_frame
	var multi_error := await _test_multiple_encounters(multi_alley)
	if not multi_error.is_empty():
		_fail(multi_error)
		return
	root.remove_child(multi_alley)
	multi_alley.free()
	await physics_frame

	# A level carries music, and the audio server needs a moment with it.
	await AudioSettle.settle(self)
	print("ENCOUNTER_SMOKE_TEST_PASS")
	quit()


## The prototype alley wires every Step 7 collaborator through typed exports
## and starts with no enemy in the tree: the encounter spawns them.
func _test_level_contract(alley: PrototypeAlley) -> String:
	if alley.player == null or alley.player.get_parent() != alley.actors:
		return "PrototypeAlley must export the Player living under Actors"
	if alley.camera == null or not alley.camera.is_current():
		return "PrototypeAlley must export the current BeltScrollCamera"
	if alley.camera.target != alley.player:
		return "The belt camera must follow the player"
	if alley.camera.limit_left != 0 or alley.camera.limit_right < 3 * int(VIEW_WIDTH):
		return "The camera limits must span at least three screens of street"
	if alley.camera.limit_bottom != int(VIEW_HEIGHT):
		return "The camera's band must end on the last road row"
	# The band rises when Billy climbs onto a ledge, so limit_top is above the
	# world origin by exactly the headroom the stage art carries there.
	if alley.camera.limit_top != int(VIEW_HEIGHT - _stage_texture_size(alley).y):
		return "limit_top must be the top of the stage art, got %d" % alley.camera.limit_top
	var edges: Array[StaticBody2D] = []
	for child: Node in alley.camera.find_children("*", "StaticBody2D", true, false):
		edges.append(child as StaticBody2D)
	if edges.size() != 2:
		return "The camera must carry exactly two screen-edge walls, found %d" % edges.size()
	for edge: StaticBody2D in edges:
		if edge.collision_layer != SCREEN_EDGE_LAYER or edge.collision_mask != 0:
			return "Screen edges must occupy only collision layer 8"
	if alley.player.collision_mask & SCREEN_EDGE_LAYER == 0:
		return "Billy must collide with the screen-edge layer"
	if alley.encounter_controller == null:
		return "PrototypeAlley must export its EncounterController"
	var encounters := alley.encounter_controllers()
	if encounters.size() != 3:
		return "PrototypeAlley must contain opening, middle, and ending encounters"
	if (
		encounters[0].name != &"OpeningEncounter"
		or encounters[1] != alley.encounter_controller
		or encounters[2].name != &"EndingEncounter"
	):
		return "The three encounters must be ordered opening, middle, ending"
	if (
		encounters[1].prerequisite != encounters[0]
		or encounters[2].prerequisite != encounters[1]
	):
		return "Encounter prerequisites must form one sequential chain"
	if not (
		encounters[0].lock_x < encounters[1].lock_x
		and encounters[1].lock_x < encounters[2].lock_x
	):
		return "Encounter trigger positions must progress across the stage"
	var encounter := alley.encounter_controller
	if encounter.state != EncounterController.IDLE:
		return "The encounter must start idle"
	if encounter.enemy_count != 3:
		return "The prototype encounter spawns three enemies"
	if encounter.enemy_scene == null or encounter.spawn_points == null:
		return "The encounter needs an enemy scene and spawn markers"
	if encounter.spawn_points.get_child_count() < 2:
		return "The encounter needs spawn markers on both sides of the locked view"
	for actor: Node in alley.actors.get_children():
		if actor is Williams:
			return "No enemy may be pre-placed; the encounter spawns them"
	if alley.hud == null or not alley.hud is CanvasLayer:
		return "PrototypeAlley must export a CanvasLayer HUD"
	var maximum_health := alley.player.health_component.maximum_health()
	if alley.hud.health_bar.max_value != maximum_health:
		return "The HUD bar must span Billy's maximum health"
	if alley.hud.health_bar.value != maximum_health:
		return "The HUD bar must start full"
	if alley.hud.message_label.visible:
		return "The HUD message must start hidden"
	if alley.exit == null:
		return "PrototypeAlley must export its Exit marker"
	if alley.exit.global_position.x < encounter.lock_x + VIEW_WIDTH / 2.0:
		return "The exit must lie beyond the locked encounter view"
	if alley.exit.global_position.x > float(alley.camera.limit_right):
		return "The exit must lie inside the camera limits"
	var background := alley.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null:
		return "PrototypeAlley needs a Background sprite"
	# The slice reaches above the world origin so the camera has headroom to
	# rise into; what is pinned is its last road row, on the band's bottom.
	if background.centered:
		return "The background must anchor its corner, not its centre"
	if not background.position.is_equal_approx(
		Vector2(0.0, VIEW_HEIGHT - background.texture.get_size().y)
	):
		return "The background's last row must rest on the band's bottom, got %s" % [
			background.position
		]
	if not background.texture.resource_path.begins_with("res://assets/stages/"):
		return "The stage art must live under assets/stages"
	var texture_size := background.texture.get_size()
	if texture_size.y < VIEW_HEIGHT or texture_size.x < 3.0 * VIEW_WIDTH:
		return "The stage slice must fill the band and run at least three screens wide"
	if texture_size.x != float(alley.camera.limit_right):
		return "The camera's right limit must end with the stage art"
	if alley.state != PrototypeAlley.PLAYING:
		return "The level must start in the playing state"
	return ""


## Existing focused slices exercise the established middle arena. The opening
## and ending arenas are disabled there so teleports cannot activate unrelated
## fights; the sequence gets its own end-to-end slice below.
func _isolate_middle_encounter(alley: PrototypeAlley) -> void:
	for encounter: EncounterController in alley.encounter_controllers():
		encounter.enabled = encounter == alley.encounter_controller


## The real stage runs three arenas in order. Reaching a later trigger cannot
## bypass its prerequisite, every clear hands control to the next encounter,
## and the exit remains gated until the ending fight is gone.
func _test_multiple_encounters(alley: PrototypeAlley) -> String:
	var encounters := alley.encounter_controllers()
	if encounters.size() != 3:
		return "Multi-encounter flow requires exactly three arenas"
	for encounter: EncounterController in encounters:
		encounter.enabled = true
	alley.camera.catch_up_speed = 0.0
	alley.player.set_physics_process(false)

	# Crossing every future trigger at once must still activate only the first
	# prerequisite-free arena.
	alley.player.global_position = Vector2(encounters[2].lock_x, 188.0)
	await physics_frame
	if encounters[0].state != EncounterController.ACTIVE:
		return "Crossing the stage must activate the opening encounter first"
	if (
		encounters[1].state != EncounterController.IDLE
		or encounters[2].state != EncounterController.IDLE
	):
		return "Later encounters activated before their prerequisites cleared"

	for encounter_index: int in range(encounters.size()):
		var encounter := encounters[encounter_index]
		if encounter.state == EncounterController.IDLE:
			alley.player.global_position = Vector2(encounter.lock_x, 188.0)
			await physics_frame
		if encounter.state != EncounterController.ACTIVE:
			return "%s did not activate after its prerequisite" % encounter.name
		var all_spawned := await _wait_until(
			func() -> bool: return encounter.spawned_count == encounter.enemy_count,
			encounter.spawn_interval_frames * encounter.enemy_count + 5
		)
		if not all_spawned:
			return "%s did not spawn all configured enemies" % encounter.name
		for actor: Node in alley.actors.get_children():
			if actor is Williams:
				actor.queue_free()
		var cleared := await _wait_until(
			func() -> bool: return encounter.state == EncounterController.CLEARED,
			5
		)
		if not cleared:
			return "%s did not clear after its enemies left" % encounter.name
		if encounter_index + 1 < encounters.size():
			var next := encounters[encounter_index + 1]
			if next.state != EncounterController.IDLE:
				return "%s did not remain idle after the previous clear" % next.name
			alley.player.global_position = Vector2(next.lock_x, 188.0)
			await physics_frame
			if next.state != EncounterController.ACTIVE:
				return "%s did not activate after the previous clear" % next.name

	if alley.state != PrototypeAlley.PLAYING:
		return "Clearing the ending encounter must not finish before the exit"
	alley.player.global_position = Vector2(alley.exit.global_position.x, 188.0)
	await physics_frame
	if alley.state != PrototypeAlley.CLEARED:
		return "The exit must finish after all three encounters clear"
	return ""


## Size of the stage art the level draws behind the belt.
func _stage_texture_size(alley: PrototypeAlley) -> Vector2:
	var background := alley.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null:
		return Vector2.ZERO
	return background.texture.get_size()


## The camera frames the full 384 px view, follows Billy along x inside the
## limits, never scrolls back toward the start, and stays on its band while
## Billy is on the ground plane.
func _test_camera_follow(alley: PrototypeAlley) -> String:
	# Pure camera behavior: the encounter must not lock the view mid-slice.
	alley.set_encounters_enabled(false)
	var camera := alley.camera
	var player := alley.player
	if not is_equal_approx(camera.view_right() - camera.view_left(), VIEW_WIDTH):
		return "The camera view must be exactly one 384 px screen wide"
	if not is_equal_approx(camera.center_x(), VIEW_WIDTH / 2.0):
		return "With Billy near the start the camera must clamp to the left limit"
	if not is_equal_approx(camera.global_position.y, VIEW_HEIGHT / 2.0):
		return "The camera must center the single vertical band"

	# A target that jumps ahead is caught up at catch_up_speed, never snapped to.
	var step := camera.catch_up_speed / float(Engine.physics_ticks_per_second)
	if step <= 0.0:
		return "The belt camera must ship with a catch-up cap"
	player.global_position = Vector2(300.0, 188.0)
	await physics_frame
	if not is_equal_approx(camera.center_x(), VIEW_WIDTH / 2.0 + step):
		return "One tick of catch-up must move the view by %f, got %f" % [
			step, camera.center_x() - VIEW_WIDTH / 2.0
		]
	var settled := await _wait_until(
		func() -> bool: return is_equal_approx(camera.center_x(), 300.0),
		120
	)
	if not settled:
		return "The camera must settle on Billy's x, got %f" % camera.center_x()
	if not is_equal_approx(camera.global_position.x, 300.0):
		return "The camera node must sit on the followed x"
	if not is_equal_approx(camera.global_position.y, VIEW_HEIGHT / 2.0):
		return "Following must not move the camera vertically"

	# A target outside the view is cut to at once: a paced pan would drive a
	# screen-edge wall through it.
	player.global_position = Vector2(800.0, 188.0)
	await physics_frame
	if not is_equal_approx(camera.center_x(), 800.0):
		return "A target outside the view must snap the camera, got %f" % camera.center_x()

	# The remaining teleports only check clamping, so drop the cap.
	camera.catch_up_speed = 0.0
	player.global_position = Vector2(750.0, 188.0)
	await physics_frame
	await physics_frame
	if not is_equal_approx(camera.center_x(), 800.0):
		return "The belt camera must not scroll backwards, got %f" % camera.center_x()

	player.global_position = Vector2(1100.0, 188.0)
	await physics_frame
	await physics_frame
	var maximum_center := float(camera.limit_right) - VIEW_WIDTH / 2.0
	if not is_equal_approx(camera.center_x(), maximum_center):
		return "The camera must clamp to the right limit, got %f" % camera.center_x()
	if not is_equal_approx(camera.view_right(), float(camera.limit_right)):
		return "At the right limit the view must end exactly on the stage art"
	return ""


## Locks never pan the view back, never push Billy out of it, pan forward at
## the catch-up cap, and unlocking pans back to Billy instead of snapping.
## lock_changed fires once per transition.
func _test_camera_lock_rules(alley: PrototypeAlley) -> String:
	alley.set_encounters_enabled(false)
	var camera := alley.camera
	var player := alley.player
	var lock_events: Array[bool] = []
	camera.lock_changed.connect(func(locked: bool) -> void: lock_events.append(locked))
	var step := camera.catch_up_speed / float(Engine.physics_ticks_per_second)

	camera.catch_up_speed = 0.0
	player.global_position = Vector2(640.0, 188.0)
	await physics_frame
	await physics_frame
	if not is_equal_approx(camera.center_x(), 640.0):
		return "Lock rules setup: the camera must sit on Billy at 640"
	camera.lock_at(640.0)
	await physics_frame
	if not camera.is_locked or not is_equal_approx(camera.center_x(), 640.0):
		return "Locking on the current center must hold it"
	camera.lock_at(500.0)
	await physics_frame
	if not is_equal_approx(camera.center_x(), 640.0):
		return "A lock behind the scroll must not pan the view back, got %f" % camera.center_x()
	if lock_events != [true]:
		return "lock_changed must fire once for the lock, got %s" % [lock_events]

	camera.catch_up_speed = step * float(Engine.physics_ticks_per_second)
	player.global_position = Vector2(camera.view_right() - 8.0, 188.0)
	camera.unlock()
	if lock_events != [true, false]:
		return "lock_changed must fire once for the unlock, got %s" % [lock_events]
	await physics_frame
	if not is_equal_approx(camera.center_x(), 640.0 + step):
		return "Unlocking must pan toward Billy by one step, got %f" % camera.center_x()
	var settled := await _wait_until(
		func() -> bool:
			return is_equal_approx(camera.center_x(), player.global_position.x),
		120
	)
	if not settled:
		return "The unlocked camera must settle on Billy, got %f" % camera.center_x()

	camera.lock_at(1200.0)
	var stop_x := player.global_position.x + VIEW_WIDTH / 2.0 - camera.target_margin
	settled = await _wait_until(
		func() -> bool: return is_equal_approx(camera.center_x(), stop_x),
		120
	)
	if not settled:
		return "A lock ahead must stop where Billy would leave the view, got %f" % camera.center_x()
	if player.global_position.x < camera.view_left() + camera.target_margin - 0.01:
		return "Billy must stay inside the locked view"
	camera.unlock()
	camera.unlock()
	if lock_events != [true, false, true, false]:
		return "Redundant unlocks must not emit, got %s" % [lock_events]
	return ""


## Reaching the lock x starts the encounter: the camera locks, three Williams
## spawn from the markers in turn targeting Billy, the screen edges hold Billy
## inside the locked view, and clearing every enemy unlocks the camera so the
## exit can finish the stage.
func _test_encounter_flow(alley: PrototypeAlley) -> String:
	var camera := alley.camera
	# Camera pacing has its own slices; this one checks the encounter.
	camera.catch_up_speed = 0.0
	var player := alley.player
	var encounter := alley.encounter_controller
	var events: Array[StringName] = []
	encounter.encounter_started.connect(func() -> void: events.append(&"started"))
	encounter.encounter_cleared.connect(func() -> void: events.append(&"cleared"))
	alley.stage_cleared.connect(func() -> void: events.append(&"stage_cleared"))
	var spawned: Array[Williams] = []
	encounter.enemy_spawned.connect(
		func(enemy: Node2D) -> void:
			spawned.append(enemy as Williams)
			# Frozen enemies keep the edge checks deterministic; they are
			# released before they are killed so the death linger runs.
			enemy.set_physics_process(false)
	)

	player.global_position = Vector2(encounter.lock_x - 40.0, 188.0)
	await physics_frame
	await physics_frame
	if encounter.state != EncounterController.IDLE or camera.is_locked:
		return "The encounter must wait until Billy reaches the lock x"

	player.global_position = Vector2(encounter.lock_x, 188.0)
	await physics_frame
	if encounter.state != EncounterController.ACTIVE:
		return "Reaching the lock x must activate the encounter"
	if events != [&"started"]:
		return "encounter_started must fire once on activation, got %s" % [events]
	if not camera.is_locked or not is_equal_approx(camera.center_x(), encounter.lock_x):
		return "Activation must lock the camera on lock_x"
	if encounter.spawned_count != 1 or spawned.size() != 1:
		return "The first enemy must spawn on the activation tick"
	if alley.state != PrototypeAlley.PLAYING:
		return "Activation must not end the stage"

	var spawned_all := await _wait_until(
		func() -> bool: return encounter.spawned_count == encounter.enemy_count,
		encounter.spawn_interval_frames * encounter.enemy_count + 5
	)
	if not spawned_all or spawned.size() != 3 or encounter.alive_count != 3:
		return "Three enemies must spawn one interval apart"
	var markers := encounter.spawn_points.get_children()
	for index: int in range(spawned.size()):
		var enemy := spawned[index]
		if enemy == null or enemy.get_parent() != alley.actors:
			return "Spawned enemies must be Williams under the Actors container"
		if enemy.target != player or not enemy.ai_component.has_target():
			return "Spawned enemies must target Billy"
		var marker := markers[index % markers.size()] as Marker2D
		if not enemy.global_position.is_equal_approx(marker.global_position):
			return "Enemy %d must spawn on marker %s" % [index, marker.name]
	var left_edge_ok := false
	var right_edge_ok := false
	for marker: Node in markers:
		var marker_x := (marker as Marker2D).global_position.x
		left_edge_ok = left_edge_ok or marker_x < camera.view_left()
		right_edge_ok = right_edge_ok or marker_x > camera.view_right()
	if not left_edge_ok or not right_edge_ok:
		return "Spawn markers must lie off screen on both sides of the locked view"

	player.global_position = Vector2(700.0, 188.0)
	for _frame: int in range(300):
		player.movement_component.move(Vector2.RIGHT)
	var expected_right := camera.view_right() - 7.0
	if not is_equal_approx(player.global_position.x, expected_right):
		return "The locked right screen edge must stop Billy at %f, got %f" % [
			expected_right, player.global_position.x
		]
	player.global_position = Vector2(500.0, 188.0)
	for _frame: int in range(300):
		player.movement_component.move(Vector2.LEFT)
	var expected_left := camera.view_left() + 7.0
	if not is_equal_approx(player.global_position.x, expected_left):
		return "The locked left screen edge must stop Billy at %f, got %f" % [
			expected_left, player.global_position.x
		]

	# One enemy leaves without ever emitting defeated (a future hazard or
	# despawn); the other two die normally. Both paths must count.
	var linger_frames := spawned[0].death_linger_frames
	spawned[0].queue_free()
	for enemy: Williams in spawned.slice(1):
		enemy.set_physics_process(true)
		enemy.health_component.take_damage(999)
	var cleared := await _wait_until(
		func() -> bool: return encounter.state == EncounterController.CLEARED,
		linger_frames + 10
	)
	if not cleared:
		return "Every enemy that is gone must count toward the clear"
	if encounter.alive_count != 0 or camera.is_locked:
		return "Clearing must unlock the camera"
	if events != [&"started", &"cleared"]:
		return "encounter_cleared must fire once, got %s" % [events]
	await physics_frame
	for actor: Node in alley.actors.get_children():
		if actor is Williams:
			return "Defeated enemies must free themselves"

	player.global_position = Vector2(760.0, 188.0)
	await physics_frame
	await physics_frame
	if not is_equal_approx(camera.center_x(), 760.0):
		return "After the clear the camera must follow Billy again"
	if encounter.enemy_defeated.get_connections().size() != 0 and encounter.alive_count != 0:
		return "The clear must leave no live enemy count"

	player.global_position = Vector2(alley.exit.global_position.x, 188.0)
	await physics_frame
	if alley.state != PrototypeAlley.CLEARED:
		return "Reaching the exit after the clear must finish the stage"
	if events != [&"started", &"cleared", &"stage_cleared"]:
		return "stage_cleared must fire once, got %s" % [events]
	if not alley.hud.message_label.visible or alley.hud.message_label.text != alley.stage_clear_message:
		return "Finishing must show the stage-clear banner"
	return ""


## The exit does nothing while the encounter is active and uncleared.
func _test_exit_requires_clear(alley: PrototypeAlley) -> String:
	alley.camera.catch_up_speed = 0.0
	var encounter := alley.encounter_controller
	alley.player.global_position = Vector2(encounter.lock_x, 188.0)
	await physics_frame
	if encounter.state != EncounterController.ACTIVE:
		return "Exit guard setup: the encounter must be active"
	alley.player.global_position = Vector2(alley.exit.global_position.x, 188.0)
	await physics_frame
	await physics_frame
	if alley.state != PrototypeAlley.PLAYING or alley.hud.message_label.visible:
		return "The exit must not finish the stage while the encounter is unresolved"
	return ""


## A disabled encounter never arms and does not gate the exit, so a level
## can be played through without the fight.
func _test_disabled_encounter_exit(alley: PrototypeAlley) -> String:
	alley.camera.catch_up_speed = 0.0
	var encounter := alley.encounter_controller
	encounter.enabled = false
	alley.player.global_position = Vector2(alley.exit.global_position.x, 188.0)
	await physics_frame
	await physics_frame
	if encounter.state != EncounterController.IDLE or encounter.spawned_count != 0:
		return "A disabled encounter must never arm"
	if alley.state != PrototypeAlley.CLEARED:
		return "Reaching the exit with a disabled encounter must finish the stage"
	return ""


## Screen edges only hold Billy: a live Williams spawned off screen walks
## through the locked view's edge toward him.
func _test_enemies_enter_locked_view(alley: PrototypeAlley) -> String:
	var camera := alley.camera
	camera.catch_up_speed = 0.0
	var encounter := alley.encounter_controller
	var player := alley.player
	player.set_physics_process(false)
	player.global_position = Vector2(encounter.lock_x, 188.0)
	await physics_frame
	if encounter.state != EncounterController.ACTIVE:
		return "The encounter must activate for the entry check"
	var enemy: Williams = null
	for actor: Node in alley.actors.get_children():
		if actor is Williams:
			enemy = actor
	if enemy == null:
		return "The first enemy must exist after activation"
	if enemy.global_position.x <= camera.view_right():
		return "The first enemy must start beyond the right screen edge"
	# Waits capture the instance id: a freed capture is itself a diagnostic.
	var enemy_id := enemy.get_instance_id()
	var entered := await _wait_until(
		func() -> bool:
			var live := instance_from_id(enemy_id) as Node2D
			return live != null and live.global_position.x < camera.view_right() - 8.0,
		enemy.ai_component.reaction_delay_frames + 120
	)
	if not entered:
		return "A live enemy must walk through the screen edge into the view"
	if enemy.state_machine.current_state != EnemyStateMachine.APPROACH:
		return "The entering enemy must be approaching Billy"
	return ""


## Reinforcements stop once Billy is dead; the ones already out just idle.
func _test_no_spawns_after_defeat(alley: PrototypeAlley) -> String:
	alley.camera.catch_up_speed = 0.0
	var encounter := alley.encounter_controller
	alley.player.global_position = Vector2(encounter.lock_x, 188.0)
	await physics_frame
	if encounter.spawned_count != 1:
		return "No-spawn setup: one enemy must be out on activation"
	alley.player.health_component.take_damage(999)
	for _frame: int in range(encounter.spawn_interval_frames * 2 + 5):
		await physics_frame
	if encounter.spawned_count != 1:
		return "No enemy may spawn after Billy dies, got %d" % encounter.spawned_count
	if alley.state != PrototypeAlley.DEFEATED:
		return "Billy's death mid-encounter must end the stage"
	return ""


## The HUD bar tracks Billy's health through signals only.
func _test_hud_health(alley: PrototypeAlley) -> String:
	var health := alley.player.health_component
	var bar := alley.hud.health_bar
	health.take_damage(10)
	if bar.value != health.maximum_health() - 10:
		return "The HUD bar must drop with damage, got %f" % bar.value
	health.take_damage(999)
	if bar.value != 0:
		return "The HUD bar must empty on death"
	return ""


## Billy's death ends the stage: after the defeat delay the game-over prompt
## appears and the attack action requests a restart.
func _test_defeat_and_restart(alley: PrototypeAlley) -> String:
	alley.encounter_controller.enabled = false
	var events: Array[StringName] = []
	alley.player_defeated.connect(func() -> void: events.append(&"defeated"))
	alley.restart_requested.connect(func() -> void: events.append(&"restart"))
	alley.player.health_component.take_damage(999)
	if alley.state != PrototypeAlley.DEFEATED or events != [&"defeated"]:
		return "Billy's death must move the level to DEFEATED once"
	await physics_frame
	if alley.hud.message_label.visible:
		return "The game-over prompt must wait for the defeat delay"
	if await _press_restart_and_count(alley) != 0:
		return "Pressing attack before the prompt must not restart"
	var prompted := await _wait_until(
		func() -> bool: return alley.hud.message_label.visible,
		alley.defeat_delay_frames + 2
	)
	if not prompted:
		return "The game-over prompt must appear after the defeat delay"
	if not alley.hud.message_label.text.begins_with(alley.game_over_message):
		return "The prompt must announce game over"
	if events != [&"defeated"]:
		return "No restart may be requested before the attack press"
	if await _press_restart_and_count(alley) != 1:
		return "Pressing attack after the prompt must request one restart"
	if events != [&"defeated", &"restart"]:
		return "restart_requested must fire exactly once, got %s" % [events]
	return ""


## Soak: the real encounter with live AI wears an idle Billy down to defeat
## without diagnostics, and the restart reloads the level when it is the
## running scene, yielding a fresh idle encounter and a full HUD bar.
func _test_live_fight_and_reload(alley: PrototypeAlley) -> String:
	var encounter := alley.encounter_controller
	# Two live punches finish him; the rest of the fight loop is covered by
	# the Williams suite and would only add seconds here.
	alley.player.health_component.take_damage(alley.player.health_component.maximum_health() - 16)
	alley.player.global_position = Vector2(encounter.lock_x, 188.0)
	var defeated := await _wait_until(
		func() -> bool: return alley.state == PrototypeAlley.DEFEATED,
		900
	)
	if not defeated:
		return "Live Williams must reach and defeat an idle Billy within 15 seconds"
	var prompted := await _wait_until(
		func() -> bool: return alley.hud.message_label.visible,
		alley.defeat_delay_frames + 2
	)
	if not prompted:
		return "The game-over prompt must follow the live defeat"

	# The reload frees the level, so the wait must not capture the node.
	var alley_id := alley.get_instance_id()
	current_scene = alley
	Input.action_press(PrototypeAlley.RESTART_ACTION)
	await physics_frame
	Input.action_release(PrototypeAlley.RESTART_ACTION)
	var reloaded := await _wait_until(
		func() -> bool:
			return (
				current_scene is PrototypeAlley
				and current_scene.get_instance_id() != alley_id
			),
		10
	)
	if not reloaded:
		return "Restart must reload the running level scene"
	var fresh := current_scene as PrototypeAlley
	await physics_frame
	if instance_from_id(alley_id) != null:
		return "The defeated level must be freed by the reload"
	if fresh.state != PrototypeAlley.PLAYING:
		return "The reloaded level must start playing"
	if fresh.encounter_controller.state != EncounterController.IDLE:
		return "The reloaded encounter must be idle"
	if fresh.player.is_dead() or fresh.hud.health_bar.value != fresh.hud.health_bar.max_value:
		return "The reloaded level must restore Billy and the HUD bar"
	if fresh.camera.is_locked:
		return "The reloaded camera must start unlocked"
	current_scene = null
	root.remove_child(fresh)
	fresh.free()
	return ""


## Presses the attack action for one physics tick and returns how many
## restarts the level requested by the end of the following tick.
func _press_restart_and_count(alley: PrototypeAlley) -> int:
	var counter: Array[int] = [0]
	var listener := func() -> void: counter[0] += 1
	alley.restart_requested.connect(listener)
	Input.action_press(PrototypeAlley.RESTART_ACTION)
	await physics_frame
	Input.action_release(PrototypeAlley.RESTART_ACTION)
	await physics_frame
	alley.restart_requested.disconnect(listener)
	return counter[0]


func _wait_until(condition: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _fail(message: String) -> void:
	push_error("ENCOUNTER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
