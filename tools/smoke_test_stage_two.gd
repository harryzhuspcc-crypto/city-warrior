extends SceneTree

const STREET := preload("res://levels/prototype_alley/prototype_alley.tscn")
const YARD := preload("res://levels/industrial_yard/industrial_yard.tscn")
const YARD_PATH := "res://levels/industrial_yard/industrial_yard.tscn"
const INDUSTRIAL_TRACK := "res://assets/audio/bgm/06_industrial_area.mp3"
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _wait_until(condition: Callable, budget: int) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _run() -> void:
	await _test_intro_and_walkable_map()
	await _test_no_skipping_fights()
	await _test_real_scene_transition_and_restart()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("STAGE_TWO_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("STAGE_TWO_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _test_intro_and_walkable_map() -> void:
	var yard := YARD.instantiate() as PrototypeAlley
	root.add_child(yard)
	await physics_frame
	var flow := yard.stage_transition
	_check(flow.is_busy() and flow.phase == StageTransition.FADE_IN, "Stage two starts with a fade-in")
	_check(not yard.player.is_physics_processing(), "Intro suppresses ordinary player control")
	_check(yard.hud.message_label.visible and yard.hud.message_label.text.contains("STAGE 2"), "Stage two title card")
	_check(yard.hud.stage_label.text == "STAGE 2 - INDUSTRIAL YARD", "Permanent stage HUD")
	_check(yard.music.stream.resource_path == INDUSTRIAL_TRACK and yard.music.loops(), "Industrial theme loops")
	_check(yard.music.bus == &"Music" and yard.music.volume_db == -6.0, "Industrial track routing/volume")
	_check(yard.actors.y_sort_enabled and yard.camera.target == yard.player, "Normal actor sorting/camera")
	var background := yard.get_node("Background") as Sprite2D
	_check(background.texture.get_size() == Vector2(1056, 576), "Complete original industrial picture dimensions")
	_check(background.position == Vector2(0, -264), "Original picture floor alignment")
	_check(yard.camera.limit_right == 1056 and yard.camera.limit_top == -264, "Camera frames the original picture")
	_check(yard.player.position == Vector2(56, 192), "Safe left-side entry")
	_check(await _wait_until(func() -> bool: return not flow.is_busy(), 100), "Intro finishes")
	_check(not flow.fade_rect.visible and not yard.hud.message_label.visible, "Intro cleans its overlay/title")
	_check(yard.player.is_physics_processing() and yard.player.input_component.is_processing_unhandled_input(), "Intro restores input/physics")
	_check(yard.player.collision_layer == 2 and yard.player.collision_mask & 129 == 129, "Intro restores world/screen collision")
	_check(not yard.player.hurtbox.is_invulnerable, "Intro restores vulnerability")
	_check(flow.has_next_stage() and flow.next_stage_path == "res://levels/woods/woods.tscn", "Stage two connects to the woods")

	# Real controls, stairs, conveyors and required jumps. Only combat is
	# bypassed; physics, camera, terrain support and encounter gating are real.
	var encounters := yard.encounter_controllers()
	_check(encounters.size() == 4, "Four industrial encounters")
	var expected_williams := [3, 2, 2, 0]
	var expected_lindas := [0, 1, 2, 0]
	var starts: Array[StringName] = []
	var clears: Array[StringName] = []
	for index: int in range(encounters.size()):
		var encounter := encounters[index]
		encounter.encounter_started.connect(func() -> void: starts.append(encounter.name))
		encounter.encounter_cleared.connect(func() -> void: clears.append(encounter.name))
		encounter.enemy_spawned.connect(func(enemy: Node2D) -> void: enemy.set_physics_process(false))
		if index > 0:
			_check(encounter.prerequisite == encounters[index - 1], "Sequential yard prerequisites")
		if index == 1:
			await _walk_to_x(yard, 232)
			Input.action_press(&"move_up")
			await _wait_until(func() -> bool: return yard.player.position.y <= 160, 50)
			Input.action_release(&"move_up")
			await _jump_to_surface(yard, 48)
			await _walk_to_x(yard, 332)
			await _jump_to_surface(yard, 80)
		elif index == 2:
			await _walk_to_x(yard, 420)
			Input.action_press(&"move_up")
			await _wait_until(func() -> bool: return yard.player.position.y <= 156, 80)
			Input.action_release(&"move_up")
			await _jump_to_surface(yard, 128)
			await _walk_to_x(yard, 500)
			await _jump_to_surface(yard, 176)
			await _jump_to_surface(yard, 208)
		for tick: int in range(600):
			if encounter.state == EncounterController.ACTIVE:
				break
			Input.action_press(&"move_right")
			await physics_frame
		Input.action_release(&"move_right")
		_check(encounter.state == EncounterController.ACTIVE and yard.camera.is_locked, "Walking reaches/locks %s" % encounter.name)
		_check(yard.state == PrototypeAlley.PLAYING, "Cannot clear before all yard waves")
		_check(await _wait_until(func() -> bool: return encounter.spawned_count == encounter.enemy_count, 160), "Complete yard wave spawns")
		var williams := 0
		var lindas := 0
		var bosses := 0
		for actor: Node in yard.actors.get_children():
			if actor is Williams:
				williams += 1
			elif actor is Linda:
				lindas += 1
			elif actor is Abobo:
				bosses += 1
			if actor is EnemyFighter:
				_check(actor.target == yard.player, "Yard enemies target Billy")
				actor.queue_free()
		_check(williams == expected_williams[index] and lindas == expected_lindas[index], "Yard mixed roster %d" % index)
		_check(bosses == (1 if index == 3 else 0), "Abobo only in final yard encounter")
		var track := "res://assets/audio/bgm/03_abobo_entrance.mp3" if index == 3 else INDUSTRIAL_TRACK
		_check(yard.music.stream.resource_path == track, "Only boss activation replaces industrial music")
		_check(await _wait_until(func() -> bool: return encounter.is_cleared(), 5), "Yard wave clears")
		_check(not yard.camera.is_locked, "Yard clear unlocks camera")
	await _walk_to_x(yard, 800)
	for tick: int in range(120):
		if yard.state == PrototypeAlley.CLEARED:
			break
		Input.action_press(&"move_up")
		await physics_frame
	Input.action_release(&"move_up")
	_check(yard.state == PrototypeAlley.CLEARED, "Stage two exit is physically reachable")
	_check(yard.player.health_component.current_health == 100, "Original plinth/girder/deck route is crossable without fall damage")
	_check(starts.size() == 4 and starts == clears, "Each yard wave starts/clears once in order")
	_check(yard.hud.message_label.text == "STAGE 2 CLEAR", "Stage-two clear banner")
	_check(not yard.music.playing and yard.stage_clear_music.playing, "Yard clear replaces gameplay music")
	for tick: int in range(yard.clear_prompt_delay_frames + 1):
		await physics_frame
	_check(yard.stage_transition.phase == StageTransition.WALK, "Stage two walks off towards Stage 3 instead of offering terminal replay")
	await AudioSettle.free_level(self, yard)


func _walk_to_x(stage: PrototypeAlley, x: float) -> void:
	var action: StringName = &"move_right" if x > stage.player.position.x else &"move_left"
	Input.action_press(action)
	for tick: int in range(300):
		if absf(stage.player.position.x - x) <= 1.6 or stage.state == PrototypeAlley.CLEARED:
			break
		await physics_frame
	Input.action_release(action)
	_check(absf(stage.player.position.x - x) <= 2.0 or (x == stage.exit.position.x and stage.state == PrototypeAlley.CLEARED), "Walking reaches original route x=%s (got %s)" % [x, stage.player.position])


func _jump_to_surface(stage: PrototypeAlley, height: float) -> void:
	stage.player.input_component.queue_jump()
	Input.action_press(&"move_right")
	var took_off := false
	var landed := false
	for tick: int in range(130):
		await physics_frame
		if stage.player.jump_component.is_airborne:
			took_off = true
		elif took_off:
			landed = is_equal_approx(stage.player.jump_component.ground_elevation, height)
			break
	Input.action_release(&"move_right")
	_check(landed, "Buffered K lands on traced original surface %s (at %s, floor %s)" % [height, stage.player.position, stage.player.jump_component.ground_elevation])


func _test_no_skipping_fights() -> void:
	for scene: PackedScene in [STREET, YARD]:
		var stage := scene.instantiate() as PrototypeAlley
		root.add_child(stage)
		await physics_frame
		_check(await _wait_until(func() -> bool: return not stage.stage_transition.is_busy(), 100), "Gate-check intro finishes")
		stage.player.set_physics_process(false)
		stage.player.position.x = stage.exit.position.x
		await physics_frame
		await physics_frame
		var encounters := stage.encounter_controllers()
		_check(encounters[0].state == EncounterController.ACTIVE, "An early exit visit starts only the first fight")
		for later: EncounterController in encounters.slice(1):
			_check(later.state == EncounterController.IDLE, "Cannot skip encounter prerequisites")
		_check(stage.state == PrototypeAlley.PLAYING and not stage.stage_transition.is_busy(), "Uncleared fights cannot trigger a walk-off")
		stage.player.health_component.take_damage(999)
		await physics_frame
		_check(stage.state == PrototypeAlley.DEFEATED and not stage.stage_transition.is_busy(), "Dead Billy never advances stages")
		await AudioSettle.free_level(self, stage)


func _test_real_scene_transition_and_restart() -> void:
	var street := STREET.instantiate() as PrototypeAlley
	root.add_child(street)
	current_scene = street
	await physics_frame
	street.player.set_physics_process(false)
	street.player.health_component.take_damage(35)
	street.set_encounters_enabled(false)
	street.player.position = Vector2(street.exit.position.x, 188)
	var old_id := street.get_instance_id()
	var requests: Array[String] = []
	street.stage_transition.transition_requested.connect(func(path: String) -> void: requests.append(path))
	await physics_frame
	await physics_frame
	_check(street.state == PrototypeAlley.CLEARED and street.stage_transition.phase == StageTransition.HOLD, "Stage one clear starts the cinematic")
	_check(not street.stage_transition.begin_outro(), "Duplicate clears cannot restart the cinematic")
	_check(not street.player.input_component.is_processing_unhandled_input(), "Walk-off blocks attack inputs")
	_check(street.player.collision_mask == 0 and street.player.hurtbox.is_invulnerable, "Cinematic player ignores edge walls/damage")
	Input.action_press(&"move_left")
	Input.action_press(&"jump")
	Input.action_press(&"attack")
	street.player.input_component.queue_attack()
	_check(await _wait_until(func() -> bool: return street.stage_transition.phase == StageTransition.FADE_OUT, 160), "Billy finishes walking offscreen")
	_check(street.player.position.x > float(street.camera.limit_right) + 40.0, "Walk-off actually exits the visible map")
	_check(street.player.visuals.animated_sprite.animation == &"walk_down" and not street.player.visuals.animated_sprite.flip_h, "Billy walks right, not a silent teleport")
	_check(not street.player.jump_component.is_airborne and not street.player.combat_component.is_attacking, "Held actions cannot interrupt walk-off")
	Input.action_release(&"move_left")
	Input.action_release(&"jump")
	Input.action_release(&"attack")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.scene_file_path == YARD_PATH, 50), "Actual scene swap reaches stage two")
	_check(requests == [YARD_PATH], "Exactly one next-stage request")
	_check(instance_from_id(old_id) == null, "Street and old actors are freed")
	if current_scene == null or current_scene.scene_file_path != YARD_PATH:
		if current_scene != null:
			var broken := current_scene
			current_scene = null
			await AudioSettle.free_level(self, broken)
		return
	var yard := current_scene as PrototypeAlley
	_check(yard.stage_transition.phase == StageTransition.FADE_IN, "Scene swap begins black then fades in")
	_check(yard.player.health_component.current_health == 100, "New stage restores Billy's health")
	_check(yard.camera.center_x() == 192.0 and yard.player.position == Vector2(56, 192), "New stage resets entry/camera")
	_check(yard.music.stream.resource_path == INDUSTRIAL_TRACK and not yard.stage_clear_music.playing, "New stage owns music without old clear cue")
	_check(await _wait_until(func() -> bool: return not yard.stage_transition.is_busy(), 100), "Scene swap restores controls after intro")
	_check(yard.player.input_component.attack_buffer_frames_remaining == 0 and not yard.player.combat_component.is_attacking, "No buffered street attack leaks into stage two")

	# Defeat/restart must reload the current industrial level, not the game's
	# main scene (the street). This also checks intro state isn't carried over.
	yard.player.health_component.take_damage(999)
	_check(await _wait_until(func() -> bool: return yard.hud.message_label.text.contains("PRESS J TO RESTART"), 100), "Stage two defeat shows restart")
	var yard_id := yard.get_instance_id()
	Input.action_press(&"attack")
	await physics_frame
	Input.action_release(&"attack")
	_check(await _wait_until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != yard_id, 15), "Stage two reloads after defeat")
	var fresh := current_scene as PrototypeAlley
	_check(fresh != null and fresh.scene_file_path == YARD_PATH, "Defeat restarts stage two, not stage one")
	if fresh != null:
		_check(fresh.player.health_component.current_health == 100 and fresh.state == PrototypeAlley.PLAYING, "Restart restores stage-two health/state")
		_check(await _wait_until(func() -> bool: return not fresh.stage_transition.is_busy(), 100), "Restart intro releases controls")
		current_scene = null
		await AudioSettle.free_level(self, fresh)
