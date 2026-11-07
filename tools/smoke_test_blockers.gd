extends SceneTree

const PLAYER := preload("res://features/actors/player/player.tscn")
const AudioSettle = preload("res://tools/lib/audio_settle.gd")
const STAGES := ["prototype_alley/prototype_alley", "industrial_yard/industrial_yard", "woods/woods", "headquarters/headquarters"]
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	for path: String in STAGES:
		await _test_stage(path)
	await _test_diagonal_face_slide()
	await AudioSettle.settle(self)
	if failures.is_empty():
		print("BLOCKERS_SMOKE_TEST_PASS")
		quit()
	else:
		for message: String in failures:
			push_error("BLOCKERS_SMOKE_TEST_FAIL: " + message)
		quit(1)


func _test_stage(path: String) -> void:
	var stage := (load("res://levels/%s.tscn" % path) as PackedScene).instantiate() as PrototypeAlley
	stage.stage_transition.fade_frames = 1
	stage.stage_transition.intro_hold_frames = 1
	stage.set_encounters_enabled(false)
	root.add_child(stage)
	for tick: int in range(4):
		await physics_frame
	stage.player.set_physics_process(false)
	var terrain := stage.get_node_or_null("Terrain") as BeltTerrainMap
	if terrain != null:
		var layout: Dictionary = terrain.layout_resource.get_meta(&"layout")
		for blocker: Dictionary in layout["blockers"]:
			var wall := terrain.get_node(String(blocker["name"])) as StaticBody2D
			var shape := wall.get_child(0) as CollisionPolygon2D
			var center := Vector2.ZERO
			var right := -INF
			for vertex: Vector2 in shape.polygon:
				center += vertex
				right = maxf(right, vertex.x)
			center /= float(shape.polygon.size())
			var query := PhysicsPointQueryParameters2D.new()
			query.position = center
			query.collision_mask = wall.collision_layer
			var found := false
			for hit: Dictionary in stage.get_world_2d().direct_space_state.intersect_point(query):
				found = found or hit["collider"] == wall
			_check(found, path + ": solid physics footprint for " + wall.name)
			stage.player.collision_mask = wall.collision_layer
			var transform := stage.player.global_transform
			transform.origin = Vector2(right + 24, center.y + 4)
			_check(stage.player.test_move(transform, center + Vector2(0,4) - transform.origin), path + ": player sweep cannot tunnel through " + wall.name)
			if not blocker.get("world_boundary", false):
				var height := float(blocker["height"])
				_check((terrain.blocker_mask_at(height,height) & wall.collision_layer) != 0, "Blocker enables at its own manifest height")
				if not blocker.get("solid_wall", false):
					_check((terrain.blocker_mask_at(height+160,height+160) & wall.collision_layer) == 0, "Upper platforms/jumps clear lower crate footprints")
	else:
		for name: String in ["TopBoundary", "BottomBoundary", "LeftBoundary", "RightBoundary"]:
			var wall := stage.get_node("WorldGeometry/" + name) as StaticBody2D
			var transform := stage.player.global_transform
			var horizontal := name in ["TopBoundary", "BottomBoundary"]
			var offset := Vector2(0,32) if horizontal else Vector2(32,0)
			transform.origin = wall.position + Vector2(0,4) + offset
			stage.player.collision_mask = 1
			_check(stage.player.test_move(transform, -offset), "Stage 1 solid " + name)
	await AudioSettle.free_level(self,stage)


func _test_diagonal_face_slide() -> void:
	# Reproduces the old early-break bug: one sub-step meets a higher face,
	# but movement parallel to that face must still make progress.
	var fixture := Node2D.new()
	root.add_child(fixture)
	var terrain := BeltTerrainMap.new()
	var layout := Resource.new()
	layout.set_meta(&"layout", {
		"image_offset_y": 0, "fall_zone_max_x": -1000, "blockers": [],
		"surfaces": [
			{"name":"Lower", "height":0, "polygon":[[0,0],[64,0],[64,64],[0,64]]},
			{"name":"Higher", "height":64, "polygon":[[64,-64],[128,-64],[128,0],[64,0]]},
		],
	})
	terrain.layout_resource = layout
	fixture.add_child(terrain)
	var player := PLAYER.instantiate() as Player
	player.position = Vector2(69.9,32)
	fixture.add_child(player)
	terrain.attach_actor(player)
	var resolved := player.terrain_motor.resolve_velocity(Vector2(240,60))
	_check(is_zero_approx(resolved.x) and resolved.y > 59, "Fast diagonal sweep keeps its unblocked axis at a higher face")
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	for tick: int in range(20):
		await physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	_check(player.position.x < 72 and player.position.y > 40, "Diagonal movement slides along a higher face instead of sticking on both axes (got %s)" % player.position)
	_check(not player.jump_component.is_airborne, "Sliding along a blocker retains floor support")
	await AudioSettle.free_level(self,fixture)
