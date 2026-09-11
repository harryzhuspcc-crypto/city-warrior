extends SceneTree

const PROTOTYPE_ALLEY_SCENE: PackedScene = preload(
	"res://levels/prototype_alley/prototype_alley.tscn"
)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
	root.add_child(alley)
	await physics_frame

	var actors := alley.actors
	if not actors.y_sort_enabled:
		_fail("Actors container is not Y-sorted")
		return
	var player := actors.get_node("Player") as Player
	if player.get_parent() != actors:
		_fail("Player is not a direct child of Actors")
		return
	if player.collision_mask & 1 == 0:
		_fail("Player does not scan world collision layer 1")
		return
	var pivot_error := _test_feet_pivots(player)
	if not pivot_error.is_empty():
		_fail(pivot_error)
		return
	if alley.get_node("WorldGeometry").get_child_count() != 4:
		_fail("Prototype alley does not have four boundaries")
		return
	var sprite_frames := player.visuals.animated_sprite.sprite_frames
	if not sprite_frames.has_animation(&"jump"):
		_fail("Billy is missing the referenced jump animation")
		return
	if sprite_frames.get_frame_count(&"jump") != 2:
		_fail("Billy's jump animation must contain exactly two referenced poses")
		return

	Input.action_press(&"jump")
	for _frame: int in range(2):
		await physics_frame
	Input.action_release(&"jump")
	if not player.jump_component.is_airborne:
		_fail("Jump input did not start the physics jump")
		return
	if player.visuals.animated_sprite.animation != &"jump":
		_fail("Airborne Billy did not select the jump animation")
		return
	if player.visuals.animated_sprite.frame != 0:
		_fail("Ascending Billy did not use the first referenced jump pose")
		return
	player.jump_component.jump_velocity = -1.0
	player.visuals.sync(
		PlayerStateMachine.IDLE,
		Vector2.RIGHT,
		true,
		player.jump_component.jump_velocity
	)
	if player.visuals.animated_sprite.frame != 1:
		_fail("Descending Billy did not use the second referenced jump pose")
		return
	player.jump_component.land_immediately()
	player.visuals.sync(PlayerStateMachine.IDLE, Vector2.RIGHT)

	player.set_physics_process(false)
	var start_position := player.global_position
	var visual_start := player.visuals.position
	var landed_count: Array[int] = [0]
	player.jump_component.landed.connect(func() -> void: landed_count[0] += 1)
	if not player.jump_component.try_jump() or player.jump_component.try_jump():
		_fail("Jump acceptance/rejection contract failed")
		return

	player.jump_component.physics_tick(1.0 / 60.0)
	if player.jump_component.jump_height <= 0.0:
		_fail("Jump height did not increase")
		return
	if player.global_position != start_position:
		_fail("Jump changed the actor ground-plane position")
		return
	if player.visuals.position.y >= visual_start.y:
		_fail("Jump did not lift only the visual node")
		return

	player.movement_component.move(Vector2.DOWN)
	player.jump_component.physics_tick(1.0 / 60.0)
	if player.global_position.y <= start_position.y:
		_fail("Airborne depth movement did not change the ground plane")
		return
	if player.jump_component.ground_position != player.global_position:
		_fail("Jump ground_position did not track belt-scroller movement")
		return

	var safety_ticks: int = 0
	var maximum_jump_height := player.jump_component.jump_height
	while player.jump_component.is_airborne and safety_ticks < 300:
		player.jump_component.physics_tick(1.0 / 60.0)
		maximum_jump_height = maxf(maximum_jump_height, player.jump_component.jump_height)
		safety_ticks += 1
	if player.jump_component.is_airborne:
		_fail("Jump did not land within its deterministic safety window")
		return
	if player.jump_component.jump_height != 0.0 or player.jump_component.jump_velocity != 0.0:
		_fail("Landing did not clamp jump values to zero")
		return
	if player.visuals.position != visual_start or landed_count[0] != 1:
		_fail("Landing did not restore visuals and emit exactly once")
		return
	if absf(maximum_jump_height - 51.0) > 0.01:
		_fail("Jump apex must be approximately double height; got %.2f px" % maximum_jump_height)
		return

	player.input_component.clear_buffered_actions()
	player.jump_component.try_jump()
	var physics_delta := 1.0 / 60.0
	while true:
		var next_velocity := (
			player.jump_component.jump_velocity
			- player.fighter_stats.jump_gravity * physics_delta
		)
		var next_height := player.jump_component.jump_height + next_velocity * physics_delta
		if next_height <= 0.0:
			break
		player.jump_component.physics_tick(physics_delta)
	player.input_component.queue_jump()
	for _frame: int in range(player.input_component.attack_buffer_frames - 1):
		player.input_component.end_physics_tick()
	player._physics_process(physics_delta)
	if not player.jump_component.is_airborne or player.jump_component.jump_velocity <= 0.0:
		_fail("Jump buffered on the final pre-landing frame was lost")
		return
	player.jump_component.land_immediately()
	player.input_component.clear_buffered_actions()

	for test_case: Array in [
		[Vector2.LEFT, Vector2(15.0, 150.0), &"left"],
		[Vector2.RIGHT, Vector2(369.0, 150.0), &"right"],
		[Vector2.UP, Vector2(192.0, 108.0), &"top"],
		[Vector2.DOWN, Vector2(192.0, 200.0), &"bottom"],
	]:
		player.global_position = Vector2(192.0, 150.0)
		for _frame: int in range(300):
			player.movement_component.move(test_case[0] as Vector2)
		var expected := test_case[1] as Vector2
		if player.global_position.distance_to(expected) > 0.01:
			_fail(
				"%s boundary failed: expected %s, got %s"
				% [test_case[2], expected, player.global_position]
			)
			return

	print("STEP_4_SMOKE_TEST_PASS")
	quit()


func _test_feet_pivots(player: Player) -> String:
	var frames := player.visuals.animated_sprite.sprite_frames
	for animation_name: StringName in frames.get_animation_names():
		for frame_index: int in range(frames.get_frame_count(animation_name)):
			var texture := frames.get_frame_texture(animation_name, frame_index)
			var image := texture.get_image()
			if image.get_width() != 80 or image.get_height() != 80:
				return "%s frame %d is not an 80x80 feet-pivot canvas" % [
					animation_name,
					frame_index,
				]
			for y: int in range(80):
				if image.get_pixel(0, y).a > 0.0 or image.get_pixel(79, y).a > 0.0:
					return "%s frame %d touches a canvas edge and may be clipped" % [
						animation_name,
						frame_index,
					]

			var minimum_x: int = 80
			var maximum_x: int = -1
			for y: int in range(72, 80):
				for x: int in range(80):
					if image.get_pixel(x, y).a > 0.0:
						minimum_x = mini(minimum_x, x)
						maximum_x = maxi(maximum_x, x)
			if maximum_x < minimum_x:
				return "%s frame %d has no floor contact" % [animation_name, frame_index]

			var contact_midpoint := (minimum_x + maximum_x + 1) * 0.5
			if absf(contact_midpoint - 40.0) > 0.5:
				return "%s frame %d feet midpoint is %.1f instead of 40" % [
					animation_name,
					frame_index,
					contact_midpoint,
				]
	return ""


func _fail(message: String) -> void:
	push_error("STEP_4_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
