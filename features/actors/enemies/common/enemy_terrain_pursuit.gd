extends RefCounted
## Small static-terrain route planner. Only opted-in enemies use this worker.
## Nodes represent actual support heights; upward links must fit a jump arc.
const CELL := 16.0
const MAX_RISE := 40.0
var body: EnemyFighter
var floors: Dictionary = {}
var path: Array[Vector2i] = []
var refresh_frames := 0
var footprint := Rect2()
var boundaries: Array[PackedVector2Array] = []


func _init(actor: EnemyFighter) -> void:
	body = actor
	var collision := actor.get_node("BodyCollision") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D
	footprint = Rect2(collision.position - rectangle.size * 0.5, rectangle.size).grow(0.5)


func direction() -> Vector2:
	if not is_instance_valid(body.target) or body._target_is_dead():
		path.clear()
		return Vector2.ZERO
	if floors.is_empty():
		_build_grid()
	refresh_frames -= 1
	if not body.terrain_motor.is_falling() and (refresh_frames <= 0 or path.is_empty()):
		_plan()
		refresh_frames = 30
	while not path.is_empty() and body.position.distance_to(_point(path[0])) < 5.0:
		path.pop_front()
	if path.is_empty():
		return Vector2.ZERO
	var next := _point(path[0])
	var rise := float(floors[path[0]]) - body.combat_elevation()
	if rise > 0.5 and rise <= MAX_RISE and not body.terrain_motor.is_falling():
		body.terrain_motor.try_enemy_jump(252.4)
	return body.position.direction_to(next)


func _point(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5


func _build_grid() -> void:
	var terrain := body.terrain_motor.terrain
	var layout: Dictionary = terrain.layout_resource.get_meta(&"layout")
	for blocker: Dictionary in layout.get("blockers", []):
		if not blocker.get("world_boundary", false):
			continue
		var polygon := PackedVector2Array()
		for vertex: Array in blocker["polygon"]:
			polygon.append(Vector2(vertex[0], vertex[1] + float(blocker["height"]) + terrain.image_offset_y))
		boundaries.append(polygon)
	var bounds := Rect2()
	for surface: Dictionary in body.terrain_motor.terrain.surfaces:
		for vertex: Array in surface["polygon"]:
			var point := Vector2(vertex[0], vertex[1] + float(surface["height"]) + body.terrain_motor.terrain.image_offset_y)
			bounds = bounds.expand(point)
	for x: int in range(int(floor(bounds.position.x / CELL)), int(ceil(bounds.end.x / CELL))):
		for y: int in range(int(floor(bounds.position.y / CELL)), int(ceil(bounds.end.y / CELL))):
			var cell := Vector2i(x, y)
			var point := _point(cell)
			var height: Variant = body.terrain_motor.terrain.floor_at(point.x, point.y)
			if height != null and not _blocked(point, float(height) + 0.5):
				floors[cell] = float(height)


func _nearest(point: Vector2, height: float) -> Vector2i:
	var best := Vector2i(-99999, -99999)
	var distance := INF
	for cell: Vector2i in floors:
		if absf(float(floors[cell]) - height) > 0.5:
			continue
		var candidate := point.distance_squared_to(_point(cell))
		if candidate < distance:
			distance = candidate
			best = cell
	return best


func _plan() -> void:
	path.clear()
	var target_height: float = body.target.visual_elevation() if body.target is Player else 0.0
	var start := _nearest(body.position, body.combat_elevation())
	var goal := _nearest(body.target.position, target_height)
	if not floors.has(start) or not floors.has(goal):
		return
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell == goal:
			break
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if previous.has(next) or not floors.has(next):
				continue
			if float(floors[next]) - float(floors[cell]) > MAX_RISE:
				continue
			if not _edge_clear(cell, next):
				continue
			previous[next] = cell
			frontier.append(next)
	if not previous.has(goal):
		return
	var cell := goal
	while cell != start:
		path.push_front(cell)
		cell = previous[cell]


func _edge_clear(from: Vector2i, to: Vector2i) -> bool:
	var ceiling := maxf(float(floors[from]), float(floors[to])) + 0.5
	for step: int in range(9):
		var point := _point(from).lerp(_point(to), float(step) / 8.0)
		if _blocked(point, ceiling):
			return false
	return true


func _blocked(point: Vector2, ceiling: float) -> bool:
	if body.terrain_motor.terrain.platform_blocks_at(point, ceiling, footprint):
		return true
	var feet := Rect2(point + footprint.position, footprint.size)
	var polygon := PackedVector2Array([feet.position, feet.position + Vector2(feet.size.x, 0), feet.end, feet.position + Vector2(0, feet.size.y)])
	for boundary: PackedVector2Array in boundaries:
		if not Geometry2D.intersect_polygons(polygon, boundary).is_empty():
			return true
	return false
