extends SceneTree
const SCENE := preload("res://levels/platform_simple_test/platform-simple-test.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	await frames(3)
	var player: Player = scene.player
	for top: Polygon2D in scene.get_node("Platforms").get_children():
		check(top._get_configuration_warnings().is_empty(), "Authored polygon has no configuration warnings: %s" % top.name)
	check(player.jump_component.ground_elevation == 32, "Starts on lower platform")
	Input.action_press(&"move_right")
	await frames(70)
	release()
	check(player.jump_component.ground_elevation == 32 and player.position.x < 310, "Upper face blocks walking")
	player.input_component.queue_jump()
	Input.action_press(&"move_right")
	await frames(45)
	release()
	check(player.jump_component.ground_elevation == 64 and not player.jump_component.is_airborne, "Right jump lands on upper platform")
	for tier: int in [1, 2]:
		scene.place_on(tier)
		Input.action_press(&"move_up")
		await frames(90)
		player.input_component.queue_jump()
		await frames(60)
		release()
		check(player.position.y >= 181.9 and player.jump_component.ground_elevation == tier * 32, "Rear wall blocks walking and airborne movement on tier %s" % tier)
		scene.place_on(tier)
		Input.action_press(&"move_down")
		await frames(95)
		release()
		await frames(30)
		check(player.jump_component.ground_elevation == 0 and not player.jump_component.is_airborne, "Front edge falls to ground on tier %s" % tier)
	# Use the outermost tier: Level3 now correctly blocks walking off Level2.
	scene.place_on(4)
	Input.action_press(&"move_right")
	await frames(130)
	release()
	await frames(30)
	check(player.jump_component.ground_elevation == 0, "Outer side falls to ground")
	scene.queue_free()
	await frames(3)
	# Edit a native Polygon2D vertex, save/reload, and verify the terrain source.
	var edited := SCENE.instantiate()
	var top: Polygon2D = edited.get_node("Platforms/Level1")
	var points := top.polygon
	points[0].x -= 20
	top.polygon = points
	top.height = 40.0
	var packed := PackedScene.new()
	check(packed.pack(edited) == OK, "Edited scene packs")
	check(ResourceSaver.save(packed, "user://platform-simple-edited.tscn") == OK, "Edited scene saves")
	edited.free()
	var saved := load("user://platform-simple-edited.tscn") as PackedScene
	edited = saved.instantiate()
	root.add_child(edited)
	await frames(3)
	var found := false
	for surface: Dictionary in edited.terrain.surfaces:
		if surface.name == "Level1":
			found = surface.polygon[0][0] == 80.0 and surface.height == 40.0
	check(found, "Saved vertex and height edits drive generated terrain")
	edited.queue_free()
	await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://platform-simple-edited.tscn"))
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("PLATFORM_SIMPLE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)
