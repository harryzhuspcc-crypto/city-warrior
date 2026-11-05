extends SceneTree
## Run this external harness against the EXPORTED pack, never editor res://.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Expected one exported scene path")
		quit(1)
		return
	var scene := load(arguments[0]) as PackedScene
	if scene == null:
		push_error("Exported scene missing: " + arguments[0])
		quit(1)
		return
	var level := scene.instantiate()
	root.add_child(level)
	await create_timer(1.5).timeout
	# Stop/free audio, then let the mixer release streams before pack teardown.
	root.remove_child(level)
	level.free()
	await create_timer(0.2).timeout
	print("WEB_EXPORT_SMOKE_TEST_PASS: " + arguments[0])
	quit()
