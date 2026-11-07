extends Node2D
## One reusable effect per level; no timers, particles or per-fall allocations.

const DURATION := 0.85
var age: float = DURATION
var kind: String = "water"


func play(point: Vector2, height: float, impact_kind: String) -> void:
	position = point + Vector2.UP * height
	kind = impact_kind
	age = 0.0
	show()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age = minf(age + delta, DURATION)
	queue_redraw()
	if age >= DURATION:
		hide()
		set_process(false)


func _draw() -> void:
	var progress := age / DURATION
	var tint := Color(0.55, 0.86, 1.0) if kind == "water" else Color(0.70, 0.64, 0.40)
	for ring: int in range(3):
		var phase := progress - float(ring) * 0.13
		if phase < 0.0 or phase > 0.8:
			continue
		var radius := 5.0 + phase * (40.0 if kind == "water" else 23.0)
		var points := PackedVector2Array()
		for vertex: int in range(33):
			var angle := TAU * float(vertex) / 32.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.25))
		var color := tint
		color.a = (1.0 - phase / 0.8) * (1.0 - progress)
		draw_polyline(points, color, 1.0)
	if kind == "water" and progress < 0.5:
		for droplet: int in range(7):
			var spread := float(droplet - 3)
			var point := Vector2(spread * progress * 17.0, -sin(progress * PI * 2.0) * (10.0 - absf(spread)))
			draw_rect(Rect2(point, Vector2(2, 2)), Color(tint, 1.0 - progress * 2.0))
