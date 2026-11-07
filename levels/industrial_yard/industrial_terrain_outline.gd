@tool
extends Polygon2D
## Editable terrain geometry over the fixed stage image.

@export var height: float = 0.0
@export var outline_color := Color(0.30, 0.49, 1.0):
	set(value):
		outline_color = value
		queue_redraw()

@export_group("Surface")
@export var solid: bool = false
@export var drop_edges: bool = false
@export var block_back_edge: bool = false
@export var landing_depth_assist: float = 0.0
@export var belt_speed: float = 0.0

@export_group("Blocker")
@export var world_boundary: bool = false
@export var solid_wall: bool = false
## A negative value leaves the maximum unrestricted.
@export var max_base_height: float = -1.0


func _draw() -> void:
	if polygon.size() < 2:
		return
	var points := polygon.duplicate()
	for index: int in range(points.size()):
		points[index] += offset
	points.append(points[0])
	draw_polyline(points, outline_color, 1.5, true)
