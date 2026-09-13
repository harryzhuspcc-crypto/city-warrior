extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://features/actors/player/player.tscn")
const LADDER_SCENE_PATH: String = "res://features/level_objects/ladder/ladder.tscn"
const PROTOTYPE_ALLEY_SCENE: PackedScene = preload(
	"res://levels/prototype_alley/prototype_alley.tscn"
)
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
const LADDER_LAYER: int = 256
## Actor bodies share collision layer 2; an elevated Billy drops it.
const ACTOR_BODY_LAYER: int = 2
## Poses in the repeating climb cycle the sheet marks REPEAT.
const CLIMB_POSE_COUNT: int = 5
## Stage row the SCOOP cornice's stone starts on: the ledge's surface, and the
## row the black cap line sits directly above in the stage art.
const LEDGE_SURFACE_Y: float = 25.0
## Columns the cornice's corbel run covers in the stage art. The ledge's
## walkable span has to stay inside them.
const CORNICE_LEFT_X: float = 493.0
const CORNICE_RIGHT_X: float = 838.0
const PHYSICS_DELTA: float = 1.0 / 60.0
## The body rests against the walkable strip's top boundary at Godot's
## physics safe margin, a sub-pixel offset from the ladder's base.
const SNAP_TOLERANCE: float = 0.2

var _ladder_scene: PackedScene


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ResourceLoader.exists(LADDER_SCENE_PATH):
		_fail("Ladder scene is missing at %s" % LADDER_SCENE_PATH)
		return
	_ladder_scene = load(LADDER_SCENE_PATH) as PackedScene

	# Every slice runs inside the real level: its boundaries, camera, and
	# ladder are what the player actually meets. The encounter is disabled
	# except in the slice that checks the two features together.
	for slice: Callable in [
		_test_level_ladder,
		_test_level_ledge,
		_test_climb_assets,
		_test_grab_and_climb,
		_test_grab_depth_does_not_change_the_top,
		_test_top_step_onto_the_ledge,
		_test_walk_the_ledge,
		_test_cross_to_the_far_ladder,
		_test_camera_rises_with_the_climb,
		_test_climb_only_ladder_clamps_at_the_top,
		_test_climb_down_and_dismount,
		_test_sideways_dismount,
		_test_no_grab_off_ladder,
		_test_no_grab_airborne,
		_test_inputs_dropped_while_climbing,
		_test_hit_ignored_while_climbing,
		_test_freed_ladder_releases,
		_test_encounter_closes_the_ladder,
		_test_encounter_waits_for_the_ground_plane,
	]:
		var alley := PROTOTYPE_ALLEY_SCENE.instantiate() as PrototypeAlley
		root.add_child(alley)
		await physics_frame
		# Climbing is the subject here; only the last slice wants a fight.
		alley.encounter_controller.enabled = false
		var error: String = await slice.call(alley)
		_release_all()
		if is_instance_valid(alley):
			root.remove_child(alley)
			alley.free()
		await physics_frame
		if not error.is_empty():
			_fail(error)
			return

	# A level carries music, and the audio server needs a moment with it.
	await AudioSettle.settle(self)
	print("LADDER_SMOKE_TEST_PASS")
	quit()


## The prototype alley places both of the SCOOP building's ladders: layer 9,
## passive, centered on the rails the art draws, based inside the walkable
## strip, leading to the ledge, and short enough that the camera - which rises
## with the climb until limit_top stops it - still frames Billy's whole sprite
## at the top.
func _test_level_ladder(alley: PrototypeAlley) -> String:
	var ladders := alley.get_tree().get_nodes_in_group(&"ladders")
	if ladders.is_empty():
		return "The prototype alley must place a Ladder"
	var tallest_pose := _tallest_climb_pose()
	if tallest_pose <= 0.0:
		return "Could not measure the climb poses"
	var ledge := _level_ledge(alley)
	# The rails the art draws: 513.5 and 529.5 on the left, 769.5 and 785.5 on
	# the right, so each ladder's centre is the midpoint of its pair.
	var expected_centres: Array[float] = [521.5, 777.5]
	var found: Array[float] = []
	for node: Node in ladders:
		var ladder := node as Ladder
		if ladder.collision_layer != LADDER_LAYER or ladder.collision_mask != 0:
			return "Ladders must occupy only collision layer 9"
		if ladder.monitoring or not ladder.monitorable:
			return "Ladders are passive areas that the player queries"
		if not ladder.is_climbable:
			return "Ladders start climbable"
		if ladder.platform != ledge:
			return "Both SCOOP ladders must lead to the one ledge"
		var base := ladder.global_position
		if ladder.top_height() < 60.0:
			return "A SCOOP ladder must be climbable for at least 60 px"
		if base.y < 152.0 or base.y > 216.0:
			return "A ladder base must sit inside the walkable strip"
		if base.y - ladder.top_height() - tallest_pose < _highest_view_top(alley):
			return "Climbing to the top must keep Billy's sprite on screen"
		for centre: float in expected_centres:
			if absf(base.x - centre) <= 1.0:
				found.append(centre)
	if found.size() != expected_centres.size():
		return "Both SCOOP ladders must stand centered on their rails, found %s" % [found]
	return ""


## The ledge is the SCOOP building's stone cornice: its surface is the row the
## art's black cap line sits on top of, its span stays inside the corbel run,
## and it reaches from the left ladder to the right one so the crossing the
## ledge exists for is possible.
func _test_level_ledge(alley: PrototypeAlley) -> String:
	var ledge := _level_ledge(alley)
	if ledge == null:
		return "The prototype alley must place the SCOOP ledge"
	var surface_y := ledge.global_position.y - ledge.height
	if not is_equal_approx(surface_y, LEDGE_SURFACE_Y):
		return "The ledge's surface must rest on the cornice at y %f, got %f" % [
			LEDGE_SURFACE_Y, surface_y
		]
	if ledge.left_x() < CORNICE_LEFT_X or ledge.right_x() > CORNICE_RIGHT_X:
		return "The ledge must stay on the cornice, got %f..%f" % [
			ledge.left_x(), ledge.right_x()
		]
	for ladder: Ladder in [_level_ladder(alley), _right_ladder(alley)]:
		if not ledge.covers_x(ladder.global_position.x):
			return "The ledge must reach the ladder at x %f" % ladder.global_position.x
		if not is_equal_approx(ladder.global_position.y, ledge.global_position.y):
			return "A ladder and its ledge must share one depth line"
	# The cornice is drawn with a black cap over its stone. Reading it out of
	# the stage texture ties the ledge to the art rather than to a number that
	# a re-crop could silently invalidate.
	var background := alley.get_node("Background") as Sprite2D
	var image := background.texture.get_image()
	var column := int(ledge.global_position.x - background.global_position.x)
	var surface_row := int(surface_y - background.global_position.y)
	var cap := image.get_pixel(column, surface_row - 1)
	var stone := image.get_pixel(column, surface_row)
	if cap.a < 1.0 or cap.v > 0.05:
		return "The row above the ledge must be the cornice's black cap, got %s" % cap
	if stone.a < 1.0 or stone.v <= 0.05:
		return "The ledge's surface must be the cornice's stone, got %s" % stone
	return ""


## Billy's SpriteFrames carries the five-pose rear climb cycle on the shared
## 80×80 feet-pivot canvas, every pose hung from one pivot column so the
## cycle does not swing sideways as the lifted leg changes.
func _test_climb_assets(alley: PrototypeAlley) -> String:
	var frames := alley.player.visuals.animated_sprite.sprite_frames
	if not frames.has_animation(&"climb"):
		return "Billy is missing the climb animation"
	if frames.get_frame_count(&"climb") != CLIMB_POSE_COUNT:
		return "The climb cycle must hold exactly five poses"
	if not frames.get_animation_loop(&"climb"):
		return "The climb cycle repeats"
	if alley.player.visuals.climb_pose_count() != CLIMB_POSE_COUNT:
		return "The visuals must report the artwork's pose count"
	var first_head: float = -1.0
	for index: int in range(CLIMB_POSE_COUNT):
		var texture := frames.get_frame_texture(&"climb", index)
		if texture == null or texture.get_size() != Vector2(80.0, 80.0):
			return "Climb pose %d must use the 80×80 feet-pivot canvas" % index
		var image := texture.get_image()
		var touches_floor := false
		for x: int in range(80):
			if image.get_pixel(x, 79).a > 0.0:
				touches_floor = true
				break
		if not touches_floor:
			return "Climb pose %d must rest its feet on the canvas floor" % index
		var head := _head_centroid_x(image)
		if head < 0.0:
			return "Climb pose %d must show Billy's head" % index
		# The head is the one part that holds still on a ladder, so the poses
		# hang from it. Centering each pose on its own feet instead would swing
		# the body sideways every time the lifted leg changes.
		if absf(head - 40.0) > 2.0:
			return "Climb pose %d must hang from the 80×80 pivot, head at %f" % [index, head]
		if first_head < 0.0:
			first_head = head
		elif absf(head - first_head) > 1.0:
			return "Climb pose %d shifts the head by %f px" % [index, head - first_head]
	return ""


## Horizontal centroid of Billy's hair, the sheet's one flat highlight color.
func _head_centroid_x(image: Image) -> float:
	var hair := Color8(255, 170, 51)
	var sum: float = 0.0
	var count: int = 0
	for y: int in range(80):
		for x: int in range(80):
			if image.get_pixel(x, y).is_equal_approx(hair):
				sum += float(x)
				count += 1
	if count == 0:
		return -1.0
	return sum / float(count)


## Up at the base grabs the ladder: Billy snaps onto it, climbs by
## climb_speed each tick, rises visually while his body stays on the ground
## plane, cycles the climb poses by distance, and cannot be hit.
func _test_grab_and_climb(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var ladder := _level_ladder(alley)
	var grounded_visual_y := player.visuals.position.y
	var events: Array[StringName] = []
	climb.climb_started.connect(func(_ladder: Ladder) -> void: events.append(&"started"))
	await _stand_beside_ladder(alley, Vector2(4.0, 6.0))
	Input.action_press(&"move_up")
	await physics_frame
	if not climb.is_climbing or player.state_machine.current_state != PlayerStateMachine.CLIMB:
		return "Up at the base must start climbing"
	if events != [&"started"]:
		return "climb_started must fire once, got %s" % [events]
	if not _is_on_ladder_base(player, ladder):
		return "Grabbing must snap Billy onto the ladder's base, got %s" % player.global_position
	if not player.hurtbox.is_invulnerable:
		return "Billy cannot be hit while on the ladder"
	var ticks := 10
	for _frame: int in range(ticks):
		await physics_frame
	var expected_height := player.fighter_stats.climb_speed * PHYSICS_DELTA * float(ticks + 1)
	if not is_equal_approx(climb.climb_height, expected_height):
		return "Ten more ticks of up must climb %f, got %f" % [expected_height, climb.climb_height]
	if not is_equal_approx(player.visuals.position.y, grounded_visual_y - climb.climb_height):
		return "The visuals must rise by the climbed height from their grounded offset"
	if not _is_on_ladder_base(player, ladder):
		return "The body must stay on the ground plane while climbing"
	var sprite := player.visuals.animated_sprite
	if sprite.animation != &"climb" or sprite.is_playing():
		return "Climbing must present the paused climb clip"
	var expected_pose := (
		int(climb.climb_height / player.fighter_stats.climb_pose_pixels) % CLIMB_POSE_COUNT
	)
	if sprite.frame != expected_pose or climb.pose_index(CLIMB_POSE_COUNT) != expected_pose:
		return "The climb pose must follow the climbed distance, expected %d got %d" % [
			expected_pose, sprite.frame
		]
	var poses_seen: Array[int] = [sprite.frame]
	var cycle_ticks := int(
		player.fighter_stats.climb_pose_pixels * float(CLIMB_POSE_COUNT)
		/ (player.fighter_stats.climb_speed * PHYSICS_DELTA)
	) + 2
	for _frame: int in range(cycle_ticks):
		await physics_frame
		if sprite.frame != poses_seen[-1]:
			poses_seen.append(sprite.frame)
	if poses_seen.size() < CLIMB_POSE_COUNT + 1:
		return "A full cycle of climbing must repeat every pose, saw %s" % [poses_seen]
	for index: int in range(1, poses_seen.size()):
		if poses_seen[index] != (poses_seen[index - 1] + 1) % CLIMB_POSE_COUNT:
			return "Climb poses must advance in order, saw %s" % [poses_seen]
	return ""


## The top of the climb is an absolute world position: grabbing from deeper
## in the strip must not leave Billy short of the top rung.
func _test_grab_depth_does_not_change_the_top(alley: PrototypeAlley) -> String:
	var player := alley.player
	var ladder := _level_ladder(alley)
	var expected_top := ladder.global_position.y - ladder.top_height()
	# The extremes of the grab zone's depth; the middle adds only climb time.
	for depth: float in [0.0, 11.0]:
		await _reset_player(alley)
		await _stand_beside_ladder(alley, Vector2(0.0, depth))
		var climbed := await _climb_onto_the_ledge(alley, ladder)
		if not climbed:
			return "A grab %f px into the strip must still reach the ledge" % depth
		var feet_y := player.global_position.y - player.climb_component.elevation()
		if absf(feet_y - expected_top) > SNAP_TOLERANCE:
			return "A grab %f px into the strip ended at %f instead of %f" % [
				depth, feet_y, expected_top
			]
	return ""


## The top rung is the ledge: Billy leaves the ladder for its surface, keeps
## his height, keeps his body on the ground plane at the ledge's depth, and
## goes back to standing rather than climbing.
func _test_top_step_onto_the_ledge(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var ledge := _level_ledge(alley)
	var grounded_visual_y := player.visuals.position.y
	var events: Array[StringName] = []
	climb.platform_entered.connect(
		func(_platform: ClimbPlatform) -> void: events.append(&"entered")
	)
	if not await _climb_onto_the_ledge(alley, _level_ladder(alley)):
		return "Holding up must carry Billy onto the ledge, got %f of %f" % [
			climb.climb_height, ledge.height
		]
	if events != [&"entered"]:
		return "platform_entered must fire once, got %s" % [events]
	if climb.is_climbing or climb.platform != ledge:
		return "The top step must leave the ladder for the ledge"
	if not is_equal_approx(climb.elevation(), ledge.height):
		return "Standing on the ledge must hold the ledge's height"
	if not is_equal_approx(player.visuals.position.y, grounded_visual_y - ledge.height):
		return "The visuals must stay raised by the ledge's height"
	if not is_equal_approx(player.global_position.y, ledge.global_position.y):
		return "The body must stay on the ground plane, on the ledge's depth line"
	var feet_y := player.global_position.y - climb.elevation()
	if not is_equal_approx(feet_y, LEDGE_SURFACE_Y):
		return "Billy's feet must land on the cornice at y %f, got %f" % [
			LEDGE_SURFACE_Y, feet_y
		]
	if player.state_machine.current_state == PlayerStateMachine.CLIMB:
		return "The ledge is walked, not climbed: the climb state must end"
	if player.visuals.animated_sprite.animation == &"climb":
		return "Standing on the ledge must leave the climb poses"
	if not player.hurtbox.is_invulnerable:
		return "Billy is still off the ground plane on the ledge"
	if player.get_collision_mask_value(ACTOR_BODY_LAYER):
		return "An elevated Billy must pass over bodies on the ground plane"
	for _frame: int in range(10):
		await physics_frame
	if not climb.is_on_platform or not is_equal_approx(climb.elevation(), ledge.height):
		return "Holding up on the ledge must change nothing"
	return ""


## The ledge is walked: left and right carry Billy along it, depth input does
## nothing up there, and each end of the span stops him rather than dropping
## him off.
func _test_walk_the_ledge(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var ledge := _level_ledge(alley)
	if not await _climb_onto_the_ledge(alley, _level_ladder(alley)):
		return "Ledge-walk setup: Billy must reach the ledge"
	var start := player.global_position
	Input.action_press(&"move_right")
	for _frame: int in range(20):
		await physics_frame
	if not climb.is_on_platform:
		return "Walking the ledge must not take Billy off it"
	if player.global_position.x <= start.x:
		return "Right must walk Billy along the ledge"
	if player.state_machine.current_state != PlayerStateMachine.MOVE:
		return "Walking the ledge must present MOVE"
	# Clear of the ladder he came up, where down is depth input rather than a
	# way back onto the rungs.
	if absf(player.global_position.x - _level_ladder(alley).global_position.x) < 16.0:
		return "Ledge-walk setup: Billy must be clear of the ladder he came up"
	var depth := player.global_position.y
	Input.action_press(&"move_down")
	for _frame: int in range(10):
		await physics_frame
	if not climb.is_on_platform:
		return "Depth input away from a ladder must not take Billy off the ledge"
	if not is_equal_approx(player.global_position.y, depth):
		return "A ledge is one depth line: depth input must not move Billy"
	_release_all()
	await physics_frame
	if player.state_machine.current_state != PlayerStateMachine.IDLE:
		return "Standing still on the ledge must present IDLE"
	# Each end stops him. Start a few pixels short so the walk, not a teleport,
	# is what meets the edge.
	for edge: Array in [[&"move_right", ledge.right_x()], [&"move_left", ledge.left_x()]]:
		var action: StringName = edge[0]
		var limit: float = edge[1]
		player.global_position.x = limit - signf(limit - ledge.global_position.x) * 6.0
		await physics_frame
		Input.action_press(action)
		for _frame: int in range(20):
			await physics_frame
		Input.action_release(action)
		if not climb.is_on_platform:
			return "Walking into the ledge's end must not drop Billy off it"
		if not is_equal_approx(player.global_position.x, limit):
			return "The ledge's end must stop Billy at %f, got %f" % [
				limit, player.global_position.x
			]
	return ""


## The crossing the ledge exists for: up the left ladder, along the cornice,
## and down the right one to the street.
func _test_cross_to_the_far_ladder(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var far_ladder := _right_ladder(alley)
	if not await _climb_onto_the_ledge(alley, _level_ladder(alley)):
		return "Crossing setup: Billy must reach the ledge"
	# Walk the last stretch so the arrival is a walk onto the far ladder's
	# grab zone rather than a teleport into it.
	player.global_position.x = far_ladder.global_position.x - 8.0
	await physics_frame
	Input.action_press(&"move_right")
	var arrived := await _wait_until(
		func() -> bool: return player.global_position.x >= far_ladder.global_position.x,
		30
	)
	Input.action_release(&"move_right")
	await physics_frame
	if not arrived or not climb.is_on_platform:
		return "Billy must walk the ledge to the far ladder"
	Input.action_press(&"move_down")
	await physics_frame
	if not climb.is_climbing or climb.ladder != far_ladder:
		return "Down over the far ladder must put Billy back on its rungs"
	if not is_equal_approx(climb.climb_height, far_ladder.top_height()):
		return "The descent must start from the ledge's own height"
	if not is_equal_approx(player.global_position.x, far_ladder.global_position.x):
		return "Stepping onto the far ladder must centre Billy on its rails"
	var down := await _wait_until(func() -> bool: return not climb.is_elevated(), 250)
	if not down:
		return "Holding down on the far ladder must reach the street"
	if not is_equal_approx(player.visuals.position.y, -40.0):
		return "Reaching the street must return the visuals to the ground"
	if player.hurtbox.is_invulnerable:
		return "Reaching the street must restore vulnerability"
	if not player.get_collision_mask_value(ACTOR_BODY_LAYER):
		return "Reaching the street must restore collision with other bodies"
	return ""


## The camera's band rises with the climb so the whole sprite stays on screen,
## stops at limit_top where the stage art ends, and comes back down.
func _test_camera_rises_with_the_climb(alley: PrototypeAlley) -> String:
	var camera := alley.camera
	var player := alley.player
	if not is_equal_approx(camera.center_y(), camera.band_center_y):
		return "The band must start on the ground plane, got %f" % camera.center_y()
	if not await _climb_onto_the_ledge(alley, _level_ladder(alley)):
		return "Camera setup: Billy must reach the ledge"
	var settled := await _wait_until(
		func() -> bool: return is_equal_approx(camera.center_y(), camera.highest_center_y()),
		60
	)
	if not settled:
		return "The band must rise to its limit, got %f of %f" % [
			camera.center_y(), camera.highest_center_y()
		]
	if camera.center_y() >= camera.band_center_y:
		return "The band must be above the ground plane while Billy is on the ledge"
	if not is_equal_approx(camera.view_top(), float(camera.limit_top)):
		return "limit_top must stop the rise at the top of the stage art"
	var head_y := player.global_position.y - player.climb_component.elevation() - _tallest_climb_pose()
	if head_y < camera.view_top():
		return "Billy's head must stay on screen on the ledge, %f above %f" % [
			head_y, camera.view_top()
		]
	player.climb_component.release()
	var lowered := await _wait_until(
		func() -> bool: return is_equal_approx(camera.center_y(), camera.band_center_y),
		90
	)
	if not lowered:
		return "Leaving the ledge must bring the band back down, got %f" % camera.center_y()
	return ""


## A ladder with no ledge is a climb-only spot: the top rung clamps it and
## holding up there changes nothing.
func _test_climb_only_ladder_clamps_at_the_top(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var spare := _spare_ladder(alley, Vector2(320.0, 180.0))
	await physics_frame
	var grounded_visual_y := player.visuals.position.y
	player.global_position = spare.global_position
	await physics_frame
	Input.action_press(&"move_up")
	var reached := await _wait_until(
		func() -> bool: return is_equal_approx(climb.climb_height, spare.climb_height),
		int(spare.climb_height / (player.fighter_stats.climb_speed * PHYSICS_DELTA)) + 10
	)
	if not reached:
		return "Holding up must reach the top rung, got %f of %f" % [
			climb.climb_height, spare.climb_height
		]
	for _frame: int in range(10):
		await physics_frame
	if climb.is_on_platform:
		return "A ladder with no ledge has nothing to step onto"
	if not climb.is_climbing or not is_equal_approx(climb.climb_height, spare.climb_height):
		return "The top rung must clamp a climb-only ladder"
	if not is_equal_approx(player.visuals.position.y, grounded_visual_y - spare.climb_height):
		return "Billy must stay on the ladder at the top"
	return ""


## Down climbs back; at the base it steps off and normal locomotion resumes.
func _test_climb_down_and_dismount(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var grounded_visual_y := player.visuals.position.y
	var events: Array[StringName] = []
	climb.climb_finished.connect(func() -> void: events.append(&"finished"))
	await _climb_for(alley, 30)
	var climbed := climb.climb_height
	if climbed <= 0.0:
		return "Dismount setup: Billy must have climbed"
	Input.action_press(&"move_down")
	await physics_frame
	var step := player.fighter_stats.climb_speed * PHYSICS_DELTA
	if not is_equal_approx(climb.climb_height, climbed - step):
		return "Down must climb back by climb_speed per tick"
	var at_base := await _wait_until(func() -> bool: return not climb.is_climbing, 40)
	if not at_base:
		return "Holding down must reach the base and step off"
	if events != [&"finished"]:
		return "climb_finished must fire once on dismount, got %s" % [events]
	if (
		not is_equal_approx(climb.climb_height, 0.0)
		or not is_equal_approx(player.visuals.position.y, grounded_visual_y)
	):
		return "Stepping off must return the visuals to the ground"
	if player.hurtbox.is_invulnerable:
		return "Stepping off must restore vulnerability"
	if player.state_machine.current_state == PlayerStateMachine.CLIMB:
		return "Stepping off must leave the climb state"
	var base_y := player.global_position.y
	await physics_frame
	if player.global_position.y <= base_y:
		return "Held down after stepping off must walk Billy down the strip"
	if player.state_machine.current_state != PlayerStateMachine.MOVE:
		return "Walking away after the ladder must present MOVE"
	return ""


## Sideways input at the base walks off the ladder; higher up it does not.
func _test_sideways_dismount(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	await _climb_for(alley, 30)
	if not climb.is_climbing:
		return "Sideways setup: Billy must be on the ladder"
	Input.action_press(&"move_right")
	for _frame: int in range(20):
		await physics_frame
	if not climb.is_climbing:
		return "Sideways input above the base must not drop Billy off the ladder"
	if not is_equal_approx(player.global_position.x, _level_ladder(alley).global_position.x):
		return "Sideways input must not slide Billy off the rungs"
	Input.action_press(&"move_down")
	var at_base := await _wait_until(
		func() -> bool: return is_zero_approx(climb.climb_height) or not climb.is_climbing,
		60
	)
	if not at_base:
		return "Sideways setup: Billy must return to the base"
	Input.action_release(&"move_down")
	var stepped_off := await _wait_until(func() -> bool: return not climb.is_climbing, 5)
	if not stepped_off:
		return "Sideways input at the base must step off the ladder"
	await physics_frame
	if player.global_position.x <= _level_ladder(alley).global_position.x:
		return "Stepping off sideways must walk Billy off the rungs"
	return ""


## Up away from the ladder base is ordinary upward walking.
func _test_no_grab_off_ladder(alley: PrototypeAlley) -> String:
	var player := alley.player
	var ladder := _level_ladder(alley)
	player.global_position = Vector2(ladder.global_position.x + 40.0, 200.0)
	await physics_frame
	Input.action_press(&"move_up")
	await physics_frame
	await physics_frame
	if player.climb_component.is_climbing:
		return "Up away from the ladder must not grab it"
	if player.global_position.y >= 200.0:
		return "Up away from the ladder must walk upward"
	Input.action_release(&"move_up")
	player.global_position = Vector2(ladder.global_position.x, ladder.global_position.y + 30.0)
	await physics_frame
	Input.action_press(&"move_up")
	await physics_frame
	if player.climb_component.is_climbing:
		return "Up below the ladder's grab zone must not grab it"
	return ""


## An airborne Billy over the base cannot grab the ladder.
func _test_no_grab_airborne(alley: PrototypeAlley) -> String:
	var player := alley.player
	await _stand_beside_ladder(alley, Vector2.ZERO)
	player.jump_component.try_jump()
	Input.action_press(&"move_up")
	await physics_frame
	await physics_frame
	if player.climb_component.is_climbing:
		return "An airborne Billy must not grab the ladder"
	player.jump_component.land_immediately()
	await physics_frame
	if not player.climb_component.is_climbing:
		return "Landing on the base with up held must grab the ladder"
	return ""


## Attack, kick, and jump presses on the ladder are dropped, not buffered:
## each is queued alone, and the last one lands one tick before the base so
## only the ladder's per-tick clear can keep it from firing on the dismount.
func _test_inputs_dropped_while_climbing(alley: PrototypeAlley) -> String:
	var player := alley.player
	var input := player.input_component
	await _climb_for(alley, 20)
	for action: Callable in [input.queue_attack, input.queue_kick, input.queue_jump]:
		action.call()
		await physics_frame
		if player.combat_component.is_attacking or player.jump_component.is_airborne:
			return "No action may start while Billy is on the ladder"
		if not player.climb_component.is_climbing:
			return "A dropped input must not end the climb"
		if (
			input.attack_buffer_frames_remaining != 0
			or input.kick_buffer_frames_remaining != 0
			or input.jump_buffer_frames_remaining != 0
		):
			return "Inputs on the ladder must be dropped, not buffered"
	# Descend to one tick above the base, queue an attack, then step off: the
	# press must die with the dismount rather than fire on the next tick.
	var step := player.fighter_stats.climb_speed * PHYSICS_DELTA
	Input.action_press(&"move_down")
	var near_base := await _wait_until(
		func() -> bool:
			return (
				not player.climb_component.is_climbing
				or player.climb_component.climb_height <= step * 1.5
			),
		120
	)
	if not near_base or not player.climb_component.is_climbing:
		return "Dropped-input setup: Billy must stop one tick above the base"
	input.queue_attack()
	await physics_frame
	if player.climb_component.is_climbing:
		return "Dropped-input setup: Billy must step off on that tick"
	Input.action_release(&"move_down")
	for _frame: int in range(input.attack_buffer_frames + 1):
		await physics_frame
		if player.combat_component.is_attacking:
			return "An attack queued on the ladder must not fire after stepping off"
	return ""


## A punch that reaches Billy on the ladder does nothing.
func _test_hit_ignored_while_climbing(alley: PrototypeAlley) -> String:
	var player := alley.player
	await _climb_for(alley, 12)
	var punch := load("res://features/combat/williams_punch.tres") as AttackData
	var health_before := player.health_component.current_health
	if player.hurtbox.receive_attack(punch, Vector2(70.0, 0.0), null):
		return "A hit must be rejected while Billy is on the ladder"
	if player.health_component.current_health != health_before:
		return "A rejected hit must not damage Billy"
	if not player.climb_component.is_climbing:
		return "A rejected hit must not knock Billy off the ladder"
	return ""


## A ladder freed under a climbing Billy steps him off instead of erroring
## on a freed node every physics tick.
func _test_freed_ladder_releases(alley: PrototypeAlley) -> String:
	var player := alley.player
	var spare := _spare_ladder(alley, Vector2(700.0, 160.0))
	await physics_frame
	player.global_position = spare.global_position
	await physics_frame
	Input.action_press(&"move_up")
	for _frame: int in range(6):
		await physics_frame
	if player.climb_component.ladder != spare:
		return "Freed-ladder setup: Billy must be on the spare ladder"
	spare.queue_free()
	await physics_frame
	await physics_frame
	if player.climb_component.is_climbing:
		return "A freed ladder must step Billy off"
	if not is_equal_approx(player.visuals.position.y, -40.0):
		return "A freed ladder must return the visuals to the ground"
	return ""


## The encounter closes every ladder so the fight cannot be sat out on an
## invulnerable rung, and clearing it opens them again.
func _test_encounter_closes_the_ladder(alley: PrototypeAlley) -> String:
	alley.encounter_controller.enabled = true
	var player := alley.player
	var ladder := _level_ladder(alley)
	var encounter := alley.encounter_controller
	# The trigger waits for the ground plane, so it can no longer catch Billy
	# on a rung; a level that starts a fight any other way still has to take
	# him off one, so the level's handler is driven from the signal itself.
	await _climb_for(alley, 10)
	if not player.climb_component.is_climbing:
		return "Encounter setup: Billy must start on the ladder"
	encounter.encounter_started.emit()
	await physics_frame
	if player.climb_component.is_elevated():
		return "Starting the encounter must take Billy off the ladder"
	if ladder.is_climbable:
		return "The encounter must close the ladders"
	if player.hurtbox.is_invulnerable:
		return "Leaving the ladder must restore vulnerability"
	await _stand_beside_ladder(alley, Vector2.ZERO)
	Input.action_press(&"move_up")
	await physics_frame
	await physics_frame
	if player.climb_component.is_climbing:
		return "A closed ladder must refuse the grab"
	Input.action_release(&"move_up")
	encounter.encounter_cleared.emit()
	await physics_frame
	if not ladder.is_climbable:
		return "Clearing the encounter must open the ladders again"
	Input.action_press(&"move_up")
	await physics_frame
	if not player.climb_component.is_climbing:
		return "An opened ladder must accept the grab again"
	return ""


## Crossing the encounter's trigger along the ledge passes over the arena, not
## into it: the fight waits until Billy is back on the ground plane, so it can
## never start by dropping him off the cornice.
func _test_encounter_waits_for_the_ground_plane(alley: PrototypeAlley) -> String:
	var player := alley.player
	var climb := player.climb_component
	var encounter := alley.encounter_controller
	encounter.enabled = true
	if encounter.lock_x <= _level_ledge(alley).left_x():
		return "This slice needs a trigger the ledge actually crosses"
	if not await _climb_onto_the_ledge(alley, _level_ladder(alley)):
		return "Trigger setup: Billy must reach the ledge"
	player.global_position.x = encounter.lock_x + 16.0
	for _frame: int in range(4):
		await physics_frame
	if encounter.state != EncounterController.IDLE:
		return "Crossing the trigger on the ledge must not arm the fight"
	if not climb.is_on_platform:
		return "An unarmed encounter must leave Billy on the ledge"
	climb.release()
	await physics_frame
	if climb.is_elevated():
		return "Trigger setup: Billy must be back on the ground plane"
	await physics_frame
	if encounter.state != EncounterController.ACTIVE:
		return "Back on the ground plane past the trigger must arm the fight"
	return ""


func _is_on_ladder_base(player: Player, ladder: Ladder) -> bool:
	return (
		is_equal_approx(player.global_position.x, ladder.global_position.x)
		and absf(player.global_position.y - ladder.global_position.y) <= SNAP_TOLERANCE
	)


func _level_ladder(alley: PrototypeAlley) -> Ladder:
	return alley.get_node("Ladders/ScoopLeftLadder") as Ladder


func _right_ladder(alley: PrototypeAlley) -> Ladder:
	return alley.get_node("Ladders/ScoopRightLadder") as Ladder


func _level_ledge(alley: PrototypeAlley) -> ClimbPlatform:
	return alley.get_node("Ledges/ScoopLedge") as ClimbPlatform


## Adds a ladder the level does not own, for the paths only a throwaway can
## reach: a climb-only spot and a ladder freed under a climber.
func _spare_ladder(alley: PrototypeAlley, base: Vector2) -> Ladder:
	var spare := _ladder_scene.instantiate() as Ladder
	spare.global_position = base
	alley.get_node("Ladders").add_child(spare)
	return spare


## Highest the camera's band can ever frame: the view top resting on the top
## of the stage art, which is where a full climb leaves it.
func _highest_view_top(alley: PrototypeAlley) -> float:
	return alley.camera.highest_center_y() - alley.camera.get_viewport_rect().size.y / 2.0


## Climbs a ladder from its base all the way onto the ledge it serves.
func _climb_onto_the_ledge(alley: PrototypeAlley, ladder: Ladder) -> bool:
	var climb := alley.player.climb_component
	alley.player.global_position = ladder.global_position
	await physics_frame
	Input.action_press(&"move_up")
	var arrived := await _wait_until(
		func() -> bool: return climb.is_on_platform,
		int(ladder.top_height() / (alley.player.fighter_stats.climb_speed * PHYSICS_DELTA)) + 20
	)
	Input.action_release(&"move_up")
	await physics_frame
	return arrived


## Places Billy beside the ladder's base, offset into the strip, and lets the
## physics server see him there.
func _stand_beside_ladder(alley: PrototypeAlley, offset: Vector2) -> void:
	alley.player.global_position = _level_ladder(alley).global_position + offset
	await physics_frame


func _climb_for(alley: PrototypeAlley, frames: int) -> void:
	await _stand_beside_ladder(alley, Vector2.ZERO)
	Input.action_press(&"move_up")
	for _frame: int in range(frames):
		await physics_frame
	Input.action_release(&"move_up")
	await physics_frame


func _reset_player(alley: PrototypeAlley) -> void:
	_release_all()
	var player := alley.player
	player.combat_component.cancel_attack()
	player.input_component.clear_buffered_actions()
	player.jump_component.land_immediately()
	player.hit_reaction_component.reset()
	player.climb_component.release()
	player.state_machine.transition_to(PlayerStateMachine.IDLE)
	await physics_frame


func _tallest_climb_pose() -> float:
	var player := PLAYER_SCENE.instantiate() as Player
	var frames := player.visuals.animated_sprite.sprite_frames
	var tallest: float = 0.0
	for index: int in range(frames.get_frame_count(&"climb")):
		var image := frames.get_frame_texture(&"climb", index).get_image()
		for y: int in range(80):
			var row_used := false
			for x: int in range(80):
				if image.get_pixel(x, y).a > 0.0:
					row_used = true
					break
			if row_used:
				tallest = maxf(tallest, 80.0 - float(y))
				break
	player.free()
	return tallest


func _release_all() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)


func _wait_until(condition: Callable, maximum_frames: int) -> bool:
	for _frame: int in range(maximum_frames):
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _fail(message: String) -> void:
	push_error("LADDER_SMOKE_TEST_FAIL: %s" % message)
	quit(1)
