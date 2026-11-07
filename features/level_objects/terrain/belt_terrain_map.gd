class_name BeltTerrainMap
extends Node2D
## Native-picture collision tracing. Polygons use source-picture coordinates;
## actor y is depth and elevation is projected separately. No map drawing.

@export var layout_resource: Resource = preload("res://assets/stages/industrial_layout.tres")
const SUPPORT_LAYER := 1024
const OBSTACLE_LAYER := 512
const ROOF_WALL_LAYER := 4096
const PLATFORM_WALL_LAYER := 8192
var surfaces: Array = []
var image_offset_y: float = -264.0
## Legacy single pit extent for Stage 2; layouts may instead list fall_zones.
var fall_zone_max_x: float = INF
## Optional depth correction on jump landings, never an expanded floor polygon.
var landing_depth_assist: float = 0.0
## Maximum automatic step; zero requires jumping onto every raised top.
var step_height: float = 18.0
var _fall_zones: Array = []
var _polygons: Array[PackedVector2Array] = []
var _bounds: Array[Rect2] = []
var hazards: Array = []
var pit_lives: int = 0
var _blockers: Array = []
var _hazard_polygons: Array[PackedVector2Array] = []
var _scoped_rear_walls: Array[StaticBody2D] = []
var _platform_walls: Array[StaticBody2D] = []


func _ready() -> void:
	var layout: Dictionary = layout_resource.get_meta(&"layout")
	surfaces = layout["surfaces"]
	image_offset_y = float(layout["image_offset_y"])
	fall_zone_max_x = float(layout.get("fall_zone_max_x", INF))
	landing_depth_assist = float(layout.get("landing_depth_assist", 0.0))
	step_height = maxf(0.0, float(layout.get("step_height", 18.0)))
	_fall_zones = layout.get("fall_zones", [])
	hazards = layout.get("hazards", [])
	pit_lives = int(layout.get("pit_lives", 0))
	_blockers = layout["blockers"]
	for hazard: Dictionary in hazards:
		var polygon := _polygon(hazard)
		_hazard_polygons.append(polygon)
	for surface: Dictionary in surfaces:
		var polygon := _polygon(surface)
		_polygons.append(polygon)
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon:
			bounds = bounds.expand(point)
		_bounds.append(bounds)
	_build_collision_shapes(layout)


func _polygon(surface: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in surface["polygon"]:
		result.append(Vector2(float(point[0]), float(point[1])))
	return result


func surface_at(x: float, ground_y: float = 192.0, ceiling: float = INF, footprint: Rect2 = Rect2()) -> Dictionary:
	var result: Dictionary = {}
	var highest := -INF
	for index: int in range(surfaces.size()):
		var entry: Dictionary = surfaces[index]
		var elevation := float(entry["height"])
		if elevation > ceiling + 0.01 or elevation < highest:
			continue
		var picture_point := Vector2(x, ground_y - elevation - image_offset_y)
		var hazard := hazard_at(Vector2(x, ground_y), elevation)
		if hazard.get("kind", "") == "hole":
			continue # Even a toe on the rim cannot provide a floor inside a hole.
		if Geometry2D.is_point_in_polygon(picture_point, _polygons[index]) or _foot_overlaps(picture_point, footprint, index):
			result = entry
			highest = elevation
	return result


func floor_at(x: float, ground_y: float = 192.0, ceiling: float = INF, footprint: Rect2 = Rect2()) -> Variant:
	var surface := surface_at(x, ground_y, ceiling, footprint)
	return null if surface.is_empty() else float(surface["height"])


func platform_blocks_at(point: Vector2, ceiling: float, footprint: Rect2) -> bool:
	for index: int in range(surfaces.size()):
		var surface: Dictionary = surfaces[index]
		var height := float(surface["height"])
		if not surface.get("solid", false) or height <= ceiling:
			continue
		var picture_point := Vector2(point.x, point.y - height - image_offset_y)
		if _foot_overlaps(picture_point, footprint, index):
			return true
	return false


func allows_fall_at(x: float) -> bool:
	if not _fall_zones.is_empty():
		for zone: Array in _fall_zones:
			if x >= float(zone[0]) and x <= float(zone[1]):
				return true
		return false
	return x <= fall_zone_max_x


func hazard_at(point: Vector2, height: float) -> Dictionary:
	for index: int in range(hazards.size()):
		var hazard: Dictionary = hazards[index]
		if not is_equal_approx(float(hazard["height"]), height):
			continue
		var picture_point := Vector2(point.x, point.y - height - image_offset_y)
		if Geometry2D.is_point_in_polygon(picture_point, _hazard_polygons[index]):
			return hazard
	return {}


func blocker_mask_at(height: float, base_height: float) -> int:
	# The manifest owns blocker elevations. Never enable another stage's
	# crate/wall layers using hard-coded industrial-yard world heights.
	var mask := 0
	for blocker: Dictionary in _blockers:
		if blocker.get("world_boundary", false):
			continue
		var bottom := float(blocker["height"]) - 16.0
		if blocker.get("solid_wall", false):
			if base_height >= bottom and base_height <= float(blocker.get("max_base_height", INF)):
				mask |= ROOF_WALL_LAYER
		elif height >= bottom and height <= float(blocker["height"]) + 32.0:
			mask |= OBSTACLE_LAYER
	return mask


func belt_at(x: float, ground_y: float = 192.0, ceiling: float = INF, footprint: Rect2 = Rect2()) -> float:
	return float(surface_at(x, ground_y, ceiling, footprint).get("belt_speed", 0.0))


func _foot_overlaps(point: Vector2, footprint: Rect2, index: int) -> bool:
	# Origins just beyond a slope/seam are not falling if the actual body
	# footprint is still standing on the top. Do not expand the map polygons
	# or bridge gaps: require a positive-area intersection with visible floor.
	if not footprint.has_area():
		return false
	var feet := Rect2(point + footprint.position, footprint.size)
	if not feet.intersects(_bounds[index]):
		return false
	var corners := PackedVector2Array([
		feet.position, feet.position + Vector2(feet.size.x, 0),
		feet.end, feet.position + Vector2(0, feet.size.y),
	])
	for contact: PackedVector2Array in Geometry2D.intersect_polygons(corners, _polygons[index]):
		var twice_area := 0.0
		for vertex: int in range(contact.size()):
			twice_area += contact[vertex].cross(contact[(vertex + 1) % contact.size()])
		if absf(twice_area) > 0.02:
			return true
	return false


func attach_actor(actor: Node2D) -> void:
	var fighter := actor as CharacterBody2D
	assert(fighter is Player or fighter is EnemyFighter, "Terrain actors require shared fighter components")
	var motor := BeltTerrainMotor.new()
	motor.body = fighter
	motor.terrain = self
	fighter.add_child(motor)
	fighter.set(&"terrain_motor", motor)
	var movement := fighter.get(&"movement_component") as MovementComponent
	movement.terrain_motor = motor
	if fighter is Player:
		fighter.jump_component.terrain_motor = motor
		motor.jump = fighter.jump_component
	motor.initialize()


func sync_platform_collisions(actor: CharacterBody2D, height: float, clearance: float, bypass: bool) -> void:
	# Each raised top has its own solid footprint. One shared mask cannot
	# distinguish a 16 px step from a tall tower at the same depth.
	actor.set_collision_mask_value(14, not bypass and not _platform_walls.is_empty())
	for wall: StaticBody2D in _platform_walls:
		if bypass or height + clearance >= float(wall.get_meta(&"top_height")):
			actor.add_collision_exception_with(wall)
		else:
			actor.remove_collision_exception_with(wall)


func sync_rear_wall_collisions(actor: CharacterBody2D, base_height: float, bypass: bool) -> void:
	# Per-body exceptions: a global layer mask would activate every stacked wall.
	for wall: StaticBody2D in _scoped_rear_walls:
		if bypass or not is_equal_approx(base_height, float(wall.get_meta(&"base_height"))):
			actor.add_collision_exception_with(wall)
		else:
			actor.remove_collision_exception_with(wall)


func _build_collision_shapes(layout: Dictionary) -> void:
	for surface: Dictionary in surfaces:
		var area := Area2D.new()
		area.name = String(surface["name"])
		area.collision_layer = SUPPORT_LAYER
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta(&"elevation", surface["height"])
		var shape := CollisionPolygon2D.new()
		shape.name = "SurfaceCollision"
		var polygon := _polygon(surface)
		var pieces: Array[PackedVector2Array] = [polygon]
		for hazard: Dictionary in hazards:
			if hazard.get("kind", "") != "hole" or float(hazard["height"]) != float(surface["height"]):
				continue
			# Split at the hole's middle before subtracting: Godot collision
			# polygons cannot represent an enclosed clockwise inner contour.
			var hole := _polygon(hazard)
			var left := hole[0].x
			var right := left
			for point: Vector2 in hole:
				left = minf(left, point.x)
				right = maxf(right, point.x)
			var center_x := (left + right) * 0.5
			var clipped: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				for slab: PackedVector2Array in [
					PackedVector2Array([Vector2(-10000,-10000), Vector2(center_x,-10000), Vector2(center_x,10000), Vector2(-10000,10000)]),
					PackedVector2Array([Vector2(center_x,-10000), Vector2(10000,-10000), Vector2(10000,10000), Vector2(center_x,10000)])
				]:
					for half: PackedVector2Array in Geometry2D.intersect_polygons(piece, slab):
						clipped.append_array(Geometry2D.clip_polygons(half, hole))
			pieces = clipped
		for index: int in range(pieces.size()):
			var piece := pieces[index]
			for vertex: int in range(piece.size()):
				piece[vertex].y += image_offset_y
			var collision := shape if index == 0 else CollisionPolygon2D.new()
			collision.polygon = piece
			area.add_child(collision)
		add_child(area)
		if surface.get("solid", false):
			var wall := StaticBody2D.new()
			wall.name = String(surface["name"]) + "Blocker"
			wall.collision_layer = PLATFORM_WALL_LAYER
			wall.collision_mask = 0
			wall.set_meta(&"top_height", surface["height"])
			var footprint := CollisionPolygon2D.new()
			footprint.name = "FootprintCollision"
			var vertices := _polygon(surface)
			for index: int in range(vertices.size()):
				vertices[index].y += image_offset_y + float(surface["height"])
			footprint.polygon = vertices
			wall.add_child(footprint)
			add_child(wall)
			_platform_walls.append(wall)
	for obstacle: Dictionary in layout["blockers"]:
		var wall := StaticBody2D.new()
		wall.name = String(obstacle["name"])
		wall.collision_layer = ROOF_WALL_LAYER if obstacle.get("solid_wall", false) else OBSTACLE_LAYER
		if obstacle.get("world_boundary", false):
			wall.collision_layer = 1
		wall.collision_mask = 0
		if obstacle.has("base_height"):
			wall.set_meta(&"base_height", obstacle["base_height"])
			_scoped_rear_walls.append(wall)
		var shape := CollisionPolygon2D.new()
		shape.name = "FootprintCollision"
		var polygon := _polygon(obstacle)
		for index: int in range(polygon.size()):
			polygon[index].y += image_offset_y + float(obstacle["height"])
		shape.polygon = polygon
		wall.add_child(shape)
		add_child(wall)
