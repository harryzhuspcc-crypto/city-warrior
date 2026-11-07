@tool
extends Polygon2D
## Draw the visible TOP with Godot's native polygon tools. Runtime terrain
## and the editor preview both read this same polygon; no second layout file.

@export_range(0, 1024, 1) var height: float = 32.0:
	set(value):
		height = value
		queue_redraw()
@export var solid: bool = true
@export var fall_from_edges: bool = true
## Edge 0 joins vertex 0 to vertex 1. Draw clockwise, starting at rear-left.
# 金色边开关：开启后在编辑器和游戏中绘制；碰撞由地形脚本另外生成。
@export var rear_wall: bool = true:
	set(value):
		rear_wall = value
		queue_redraw()
# 选择金色边：0 表示顶点 0 到顶点 1；修改后请求重绘。
@export_range(0, 31, 1) var rear_edge: int = 0:
	set(value):
		rear_edge = value
		queue_redraw()
@export var show_depth_footprint: bool = false:
	set(value):
		show_depth_footprint = value
		queue_redraw()

## Disable faces when the background already contains the platform artwork.
@export var draw_side_faces: bool = true:
	set(value):
		draw_side_faces = value
		queue_redraw()
## Stacked artwork needs a rear wall only on this floor, not through floors below.
@export var rear_wall_on_level_only: bool = false
@export var landing_depth_assist: float = 0.0
@export var belt_speed: float = 0.0

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	var corners := polygon.duplicate()
	for index: int in range(corners.size()):
		corners[index] += offset
	if corners.size() < 3:
		return
	# Front/side faces descend from the authored top to ground level.
	for index: int in range(corners.size()):
		var a := corners[index]
		var b := corners[(index + 1) % corners.size()]
		if draw_side_faces and (b.x < a.x or (is_equal_approx(b.x, a.x) and b.y < a.y)):
			draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, height), a + Vector2(0, height)]), color.darkened(0.35))
	var outline := corners.duplicate()
	outline.append(corners[0])
	draw_polyline(outline, Color("a9dcff"), 2.0, true)
	if rear_wall: # 开关开启时，额外绘制金色边
		var a := corners[rear_edge % corners.size()] # 起点：边编号取余，避免超出顶点数组
		var b := corners[(rear_edge + 1) % corners.size()] # 终点：下一个顶点，最后一条边连回顶点 0
		draw_line(a, b, Color("ffbd59"), 5.0, true) # 金色、线宽 5、抗锯齿；只画线，不创建碰撞
	if Engine.is_editor_hint() and show_depth_footprint:
		for index: int in range(outline.size()):
			outline[index] += Vector2(0, height)
		draw_polyline(outline, Color(0.8, 0.9, 1.0, 0.45), 1.0, true)
		for point: Vector2 in corners:
			draw_dashed_line(point, point + Vector2(0, height), Color(0.8, 0.9, 1.0, 0.3), 1.0, 4.0)

func top_points_in(map: Node2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in polygon:
		result.append(map.to_local(to_global(point + offset)))
	return result

func _get_configuration_warnings() -> PackedStringArray:
	if polygon.size() < 3 or Geometry2D.triangulate_polygon(polygon).is_empty():
		return PackedStringArray(["Draw a simple closed polygon with at least three vertices; edges must not cross."])
	if Geometry2D.is_polygon_clockwise(polygon):
		return PackedStringArray(["Use clockwise order on screen (rear-left, rear-right, front-right, front-left)."])
	if not is_equal_approx(global_scale.x, 1.0) or not is_equal_approx(global_scale.y, 1.0) or not is_zero_approx(global_rotation):
		return PackedStringArray(["Move the node or edit its vertices; leave rotation at 0 and scale at 1."])
	return PackedStringArray()

## Both scene adapters use this exact selected-edge projection.
func rear_wall_entry(points: PackedVector2Array) -> Dictionary:
	if not rear_wall or points.size() < 3:
		return {}
	var index := rear_edge % points.size()
	var a := points[index] + Vector2(0, height)
	var b := points[(index + 1) % points.size()] + Vector2(0, height)
	var edge := b - a
	var outward := Vector2(edge.y, -edge.x).normalized() * 12.0
	var entry := {"name": str(name) + "RearWall", "height": 0.0, "world_boundary": true,
		"polygon": [[a.x, a.y], [b.x, b.y], [b.x + outward.x, b.y + outward.y], [a.x + outward.x, a.y + outward.y]]}
	if rear_wall_on_level_only:
		entry["base_height"] = height
	return entry
