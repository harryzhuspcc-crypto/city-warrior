class_name TimedWallTrap
extends Node2D
## One square masonry block, not a moving wall panel. A shared perspective
## projection drives the stone's mesh, shadow, Y-sort depth and lethal sweep.

signal struck(player: Player)
signal phase_changed(phase: StringName)

const SAFE: StringName = &"safe"
const WARNING: StringName = &"warning"
const EXTENDING: StringName = &"extending"
const HOLDING: StringName = &"holding"
const RETRACTING: StringName = &"retracting"
const PERIOD_FRAMES := 240
const WARNING_START := 123
const THRUST_START := 168
const HOLD_START := 180
const RETRACT_START := 216
const REACH := 64.0
const PERSPECTIVE_GROWTH := 0.35
const FORWARD_SKEW := -12.0

@export var player: Player
@export var face_texture: Texture2D
@export var thrust_audio: AudioStreamPlayer2D
@export var warning_audio: AudioStreamPlayer2D
@export var phase_offset_frames: int = 0
## Original stone position relative to the panel's floor anchor. The other
## stones and the architectural frame remain untouched in the background.
@export var block_offset := Vector2(32, -32)

var enabled: bool = false
var elapsed_frames: int = 0
var phase: StringName = SAFE
var extension: float = 0.0
var _origin: Vector2
var _previous_feet: Rect2
var _footprint: Rect2
var _cycle_frame: int = 0


func _ready() -> void:
	assert(player != null and face_texture != null, "Wall trap needs player and carved face")
	assert(face_texture.get_width() == 24 and face_texture.get_height() == 24, "Wall trap moves one 24px square stone")
	_origin = position
	var collision := player.get_node("BodyCollision") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D
	_footprint = Rect2(collision.position - rectangle.size * 0.5, rectangle.size)
	_previous_feet = _player_feet()
	# Resolve after Billy has moved, including a fast attack or diagonal jump.
	process_physics_priority = 20


func _physics_process(_delta: float) -> void:
	if not enabled:
		_previous_feet = _player_feet()
		return
	elapsed_frames += 1
	apply_clock(elapsed_frames)
	var feet := _player_feet()
	if extension > 0.0 and not player.is_dead():
		if _touches_block(feet.merge(_previous_feet)):
			# Environmental crushing intentionally bypasses combat i-frames.
			# Jumping is not a bypass for this lethal environmental strike.
			player.health_component.take_damage(player.health_component.current_health)
			struck.emit(player)
	_previous_feet = feet


func _player_feet() -> Rect2:
	return Rect2(player.global_position + _footprint.position, _footprint.size)


func danger_rect() -> Rect2:
	var polygon := danger_polygon()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		bounds = bounds.expand(point)
	return bounds


func socket_rect() -> Rect2:
	var origin: Vector2 = (get_parent() as Node2D).to_global(_origin + block_offset)
	return Rect2(origin, face_texture.get_size())


## Local to the ORIGINAL anchor, not the moving Y-sort origin. Perspective
## makes the front face grow and skew sideways as it approaches the viewer.
func projected_front(distance: float = -1.0) -> Rect2:
	if distance < 0.0:
		distance = extension
	var amount := clampf(distance / REACH, 0.0, 1.0)
	var back := Rect2(block_offset, face_texture.get_size())
	var size := (back.size * (1.0 + PERSPECTIVE_GROWTH * amount)).round()
	var center_x := back.get_center().x + FORWARD_SKEW * amount
	# The original stone sits 8px above the floor. Its approaching lower edge
	# meets exactly the lethal floor extent, rather than sliding a panel down.
	var bottom := back.end.y * (1.0 - amount) + distance
	return Rect2(Vector2(center_x - size.x * 0.5, bottom - size.y).round(), size)


func _floor_polygon(distance: float) -> PackedVector2Array:
	var back := Rect2(block_offset, face_texture.get_size())
	var front := projected_front(distance)
	return PackedVector2Array([
		Vector2(back.position.x, 0), Vector2(back.end.x, 0),
		Vector2(front.end.x, distance), Vector2(front.position.x, distance),
	])


func danger_polygon() -> PackedVector2Array:
	var polygon := _floor_polygon(extension)
	var container := get_parent() as Node2D
	for index: int in range(polygon.size()):
		polygon[index] = container.to_global(_origin + polygon[index])
	return polygon


func _touches_block(feet: Rect2) -> bool:
	if not danger_rect().intersects(feet):
		return false
	var corners := PackedVector2Array([
		feet.position, Vector2(feet.end.x, feet.position.y),
		feet.end, Vector2(feet.position.x, feet.end.y),
	])
	return not Geometry2D.intersect_polygons(corners, danger_polygon()).is_empty()


func apply_clock(frame: int) -> void:
	var cycle := posmod(frame + phase_offset_frames, PERIOD_FRAMES)
	_cycle_frame = cycle
	var next_phase := SAFE
	extension = 0.0
	if cycle >= RETRACT_START:
		next_phase = RETRACTING
		var amount := float(cycle - RETRACT_START) / float(PERIOD_FRAMES - RETRACT_START)
		extension = REACH * (1.0 - smoothstep(0.0, 1.0, amount))
	elif cycle >= HOLD_START:
		next_phase = HOLDING
		extension = REACH
	elif cycle >= THRUST_START:
		next_phase = EXTENDING
		var amount := float(cycle - THRUST_START + 1) / float(HOLD_START - THRUST_START)
		extension = REACH * (1.0 - pow(1.0 - amount, 3.0))
	elif cycle >= WARNING_START:
		next_phase = WARNING
	if next_phase != phase:
		phase = next_phase
		if phase == EXTENDING and thrust_audio != null:
			thrust_audio.play()
		if phase == WARNING and warning_audio != null:
			warning_audio.play()
		phase_changed.emit(phase)
	position = _origin + Vector2(0, extension)
	queue_redraw()


func _draw() -> void:
	if face_texture == null:
		return
	# The node advances ONLY for Y sorting. Cancel that offset for the fixed
	# socket and project each cuboid vertex explicitly in the same frame.
	var undo_sort := Vector2(0, -extension)
	var back := Rect2(block_offset + undo_sort, face_texture.get_size())
	var front := projected_front()
	front.position += undo_sort
	var back_tl := back.position
	var back_tr := Vector2(back.end.x, back.position.y)
	var front_tl := front.position
	var front_tr := Vector2(front.end.x, front.position.y)
	if phase == WARNING:
		var warning := Color(1.0, 0.72, 0.15, 0.85)
		var footprint := _floor_polygon(REACH)
		draw_colored_polygon(footprint, Color(1.0, 0.55, 0.05, 0.12))
		var outline := footprint.duplicate()
		outline.append(footprint[0])
		draw_polyline(outline, warning, 1.0)
		draw_rect(back.grow(1.0), warning, false, 1.0)
		var middle := (footprint[2] + footprint[3]) * 0.5
		for y: int in [16, 32, 48]:
			var x := lerpf(back.get_center().x, middle.x, float(y) / REACH)
			draw_polyline(PackedVector2Array([Vector2(x - 3, y - 3), Vector2(x, y), Vector2(x + 3, y - 3)]), warning, 1.0)
	if extension > 0.0:
		var shadow := _floor_polygon(extension)
		for index: int in range(shadow.size()):
			shadow[index] += undo_sort + Vector2(5, 4)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
		# A dark recess opens behind ONLY the selected stone. Textured, lit top
		# and shaded right faces join that fixed socket to the approaching face.
		draw_rect(back.grow(1.0), Color("24170f"))
		_draw_stone_face(PackedVector2Array([back_tl, back_tr, front_tr, front_tl]), Color("9b825f"), Color("e4c28d"))
		_draw_stone_face(PackedVector2Array([back_tr, back.end, front.end, front_tr]), Color("493625"), Color("89623f"))
		draw_texture_rect(face_texture, front, false)
		draw_line(front_tl, front_tr, Color("e5bc7b"), 1.0)
		draw_polyline(PackedVector2Array([back_tr, front_tr, front.end]), Color("3b281b"), 1.0)
		# A brief puff at full extension sells the impact without stretching
		# the masonry or changing the deterministic collision timing.
		if phase == HOLDING and _cycle_frame < HOLD_START + 8:
			var age := float(_cycle_frame - HOLD_START) / 8.0
			for side: float in [-1.0, 1.0]:
				var dust := Vector2(front.get_center().x + side * (front.size.x * 0.5 + age * 7), front.end.y - age * 5)
				draw_rect(Rect2(dust.round(), Vector2(2, 2)), Color(0.72, 0.56, 0.36, 1.0 - age))
	var lamp := Color("ffd463") if phase == WARNING else Color("e46b38") if extension > 0.0 else Color("83aa61")
	draw_rect(Rect2(back.get_center().x - 1, back.position.y - 3, 2, 1), lamp)


func _draw_stone_face(points: PackedVector2Array, rear_tint: Color, front_tint: Color) -> void:
	draw_polygon(points, PackedColorArray([rear_tint, rear_tint, front_tint, front_tint]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), face_texture)
