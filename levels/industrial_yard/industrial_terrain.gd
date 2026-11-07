extends BeltTerrainMap
## Use editor-authored outlines for the industrial stage's terrain geometry.

const EditablePlatform = preload("res://levels/platform_simple_test/editable_platform.gd")
const TerrainOutline = preload("res://levels/industrial_yard/industrial_terrain_outline.gd")

@export var outlines: Node2D


func _ready() -> void:
	var layout: Dictionary = layout_resource.get_meta(&"layout").duplicate()
	var picture_offset := Vector2(0, float(layout["image_offset_y"]))
	var authored_surfaces: Array = []
	var authored_blockers: Array = []
	for child: Node in outlines.get_node("Surfaces").get_children():
		var platform := child as EditablePlatform
		if platform == null:
			continue
		var entry := _entry(platform, picture_offset)
		if entry.is_empty():
			continue
		entry["solid"] = platform.solid
		entry["drop_edges"] = platform.fall_from_edges
		entry["landing_depth_assist"] = platform.landing_depth_assist
		entry["belt_speed"] = platform.belt_speed
		authored_surfaces.append(entry)
		var points: PackedVector2Array = platform.top_points_in(self)
		for index: int in range(points.size()):
			points[index] -= picture_offset
		var rear: Dictionary = platform.rear_wall_entry(points)
		if not rear.is_empty():
			authored_blockers.append(rear)

	for child: Node in outlines.get_node("Blockers").get_children():
		var outline := child as TerrainOutline
		if outline == null:
			continue
		var entry := _entry(outline, picture_offset)
		if entry.is_empty():
			continue
		entry["world_boundary"] = outline.world_boundary
		entry["solid_wall"] = outline.solid_wall
		if outline.max_base_height >= 0.0:
			entry["max_base_height"] = outline.max_base_height
		authored_blockers.append(entry)

	layout["surfaces"] = authored_surfaces
	layout["blockers"] = authored_blockers
	layout_resource = Resource.new()
	layout_resource.set_meta(&"layout", layout)
	super._ready()


func _entry(outline: Polygon2D, picture_offset: Vector2) -> Dictionary:
	var polygon := outline.polygon
	if polygon.size() < 3 or Geometry2D.triangulate_polygon(polygon).is_empty():
		push_warning("Ignoring invalid terrain outline: %s" % outline.name)
		return {}
	var vertices: Array = []
	for point: Vector2 in polygon:
		var picture_point := to_local(outline.to_global(point + outline.offset)) - picture_offset
		vertices.append([picture_point.x, picture_point.y])
	return {"name": str(outline.name), "polygon": vertices, "height": outline.get("height")}
