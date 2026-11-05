class_name BeltTerrainMap
extends Node2D
## Native-picture collision tracing. Polygons use source-picture coordinates;
## actor y is depth and elevation is projected separately. No map drawing.

@export var layout_resource: Resource = preload("res://assets/stages/industrial_layout.tres")
const SUPPORT_LAYER := 1024
const OBSTACLE_LAYER := 512
const ROOF_WALL_LAYER := 4096
var surfaces: Array = []
var image_offset_y: float = -264.0
## Legacy single pit extent for Stage 2; layouts may instead list fall_zones.
var fall_zone_max_x: float = INF
## Optional depth correction on jump landings, never an expanded floor polygon.
var landing_depth_assist: float = 0.0
var _fall_zones: Array = []
var _polygons: Array[PackedVector2Array] = []
var _bounds: Array[Rect2] = []


func _ready() -> void:
	var layout: Dictionary = layout_resource.get_meta(&"layout")
	surfaces = layout["surfaces"]
	image_offset_y = float(layout["image_offset_y"])
	fall_zone_max_x = float(layout.get("fall_zone_max_x", INF))
	landing_depth_assist = float(layout.get("landing_depth_assist", 0.0))
	_fall_zones = layout.get("fall_zones", [])
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
		if Geometry2D.is_point_in_polygon(picture_point, _polygons[index]) or _foot_overlaps(picture_point, footprint, index):
			result = entry
			highest = elevation
	return result


func floor_at(x: float, ground_y: float = 192.0, ceiling: float = INF, footprint: Rect2 = Rect2()) -> Variant:
	var surface := surface_at(x, ground_y, ceiling, footprint)
	return null if surface.is_empty() else float(surface["height"])


func allows_fall_at(x: float) -> bool:
	if not _fall_zones.is_empty():
		for zone: Array in _fall_zones:
			if x >= float(zone[0]) and x <= float(zone[1]):
				return true
		return false
	return x <= fall_zone_max_x


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
		for index: int in range(polygon.size()):
			polygon[index].y += image_offset_y
		shape.polygon = polygon
		area.add_child(shape)
		add_child(area)
	for obstacle: Dictionary in layout["blockers"]:
		var wall := StaticBody2D.new()
		wall.name = String(obstacle["name"])
		wall.collision_layer = ROOF_WALL_LAYER if obstacle.get("solid_wall", false) else OBSTACLE_LAYER
		if obstacle.get("world_boundary", false):
			wall.collision_layer = 1
		wall.collision_mask = 0
		var shape := CollisionPolygon2D.new()
		shape.name = "FootprintCollision"
		var polygon := _polygon(obstacle)
		for index: int in range(polygon.size()):
			polygon[index].y += image_offset_y + float(obstacle["height"])
		shape.polygon = polygon
		wall.add_child(shape)
		add_child(wall)
