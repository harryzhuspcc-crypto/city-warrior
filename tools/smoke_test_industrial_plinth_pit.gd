extends SceneTree
## Reproduce walking DOWN off the concrete's right/front corner, not jumping right.
const LAB := preload("res://levels/industrial_yard/industrial_blocks_test.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _frames(count: int) -> void:
	for tick: int in range(count):
		await physics_frame
func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
func _run() -> void:
	# Saved user configuration, then legacy fall-zone-only configuration.
	await _test_corner(true)
	await _test_corner(false)
	for failure: String in failures:
		push_error(failure)
	if failures.is_empty():
		print("INDUSTRIAL_PLINTH_PIT_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)

func _test_corner(drop_edges: bool) -> void:
	var scene := LAB.instantiate()
	scene.get_node("PlatformBlocks/CollisionOutlines/Surfaces/ConcretePlinth").fall_from_edges = drop_edges
	root.add_child(scene)
	await _frames(3)
	var player: Player = scene.player
	player.position = Vector2(360, 168)
	player.jump_component.ground_elevation = 48
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()
	await _frames(3)
	var falls: Array[int] = []
	player.terrain_motor.fell_into_pit.connect(func() -> void: falls.append(1))
	var lives_before := player.terrain_motor.remaining_lives
	var relandings := 0
	var was_airborne := false
	var minimum := 48.0
	Input.action_press(&"move_down")
	for tick: int in range(160):
		await physics_frame
		minimum = minf(minimum, player.terrain_motor.elevation())
		if was_airborne and not player.jump_component.is_airborne and player.jump_component.ground_elevation == 48:
			relandings += 1
		was_airborne = player.jump_component.is_airborne
		if not falls.is_empty():
			break
	Input.action_release(&"move_down")
	print("PLINTH_DOWN drop_edges=", drop_edges, " position=", player.position, " min_height=", minimum, " relandings=", relandings, " falls=", falls.size(), " lives=", lives_before, "->", player.terrain_motor.remaining_lives)
	_check(relandings <= 1, "Walking off must not repeatedly snap back onto the concrete")
	_check(falls.size() == 1, "Down across the concrete corner reaches the real pit once")
	_check(lives_before > 1 and player.terrain_motor.remaining_lives == lives_before - 1, "Pit consumes exactly one life")
	await _frames(100)
	_check(not player.jump_component.is_airborne and player.terrain_motor.elevation() >= 0, "Pit resets to a stable supported checkpoint")
	_check(falls.size() == 1, "Recovery does not repeat the pit fall while idle")
	scene.queue_free()
	await _frames(3)
