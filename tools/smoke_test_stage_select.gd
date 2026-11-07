extends SceneTree

const MENU := preload("res://features/stage_flow/stage_select.tscn")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _until(condition: Callable, budget: int = 180) -> bool:
	for tick: int in range(budget):
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://features/stage_flow/stage_select.tscn", "Only City Warrior starts at its stage picker")
	for index: int in range(4):
		var menu := MENU.instantiate()
		root.add_child(menu)
		current_scene = menu
		await process_frame
		_check(menu.buttons.get_child_count() == 4 and menu.buttons.get_child(0).has_focus(), "Four stages with keyboard focus")
		_check(not menu.start_stage(-1) and not menu.start_stage(4), "Invalid stage indexes are rejected")
		var path: String = menu.STAGES[index]
		# Test the actual button path, loading, replacement and freeing.
		var menu_id := menu.get_instance_id()
		if index == 3:
			# Exercise the single-threaded Web loading branch on native CI too.
			menu.pending_path = path
			menu._load_on_main_thread.call_deferred()
		elif index == 1:
			var digit := InputEventKey.new()
			digit.keycode = KEY_2
			digit.pressed = true
			menu._unhandled_key_input(digit)
		else:
			(menu.buttons.get_child(index) as Button).pressed.emit()
		_check(not menu.start_stage((index + 1) % 4), "Double launch is ignored")
		_check(await _until(func() -> bool: return current_scene != null and current_scene is PrototypeAlley), "Stage %s loads from the menu" % (index+1))
		if not current_scene is PrototypeAlley:
			break
		var stage := current_scene as PrototypeAlley
		_check(stage.scene_file_path == path and instance_from_id(menu_id) == null, "Selection starts the exact chosen stage and frees menu")
		_check(stage.player.health_component.current_health == 100, "Selected stage has fresh combat health")
		stage.set_encounters_enabled(false)
		var stage_id := stage.get_instance_id()
		if index % 2 == 0:
			stage.hud.stage_selection_requested.emit()
		else:
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			stage._unhandled_key_input(escape)
		_check(await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path.ends_with("stage_select.tscn")), "HUD button / Esc returns to picker from Stage %s" % (index+1))
		_check(instance_from_id(stage_id) == null, "Returning frees actors, traps, projectiles and stage music")
		var fresh_menu := current_scene
		current_scene = null
		await AudioSettle.free_level(self,fresh_menu)
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("STAGE_SELECT_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("STAGE_SELECT_SMOKE_TEST_FAIL: " + message)
		quit(1)
