extends BeltTerrainMap
## Build the shared movement model from saved, visually editable scene nodes.

@export var platforms_path: NodePath = ^"../Platforms"

func _ready() -> void:
	var authored_surfaces: Array = []
	var authored_blockers: Array = []
	for platform: Polygon2D in get_node(platforms_path).get_children():
		var points: PackedVector2Array = platform.top_points_in(self)
		assert(points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty(), "Platform needs a valid simple polygon")
		var vertices: Array = []
		for point: Vector2 in points:
			vertices.append([point.x, point.y])
		authored_surfaces.append({
			"name": str(platform.name), "polygon": vertices,
			"height": platform.height, "solid": platform.solid,
			"drop_edges": platform.fall_from_edges,
		})
		var rear: Dictionary = platform.rear_wall_entry(points)
		if not rear.is_empty():
			authored_blockers.append(rear)
	layout_resource = Resource.new()
	layout_resource.set_meta(&"layout", {"surfaces": authored_surfaces, "blockers": authored_blockers,
		"image_offset_y": 0.0, "step_height": 0.0, "fall_zone_max_x": -1.0})
	super._ready()
