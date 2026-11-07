extends Node2D

@onready var player: Player = $Player
@onready var terrain: BeltTerrainMap = $Terrain
@onready var camera: BeltScrollCamera = $Camera2D
@onready var outlines: Node2D = $PlatformBlocks/CollisionOutlines
@onready var status: Label = $HUD/Status


func _ready() -> void:
	terrain.attach_actor(player)


func _physics_process(_delta: float) -> void:
	camera.band_center_y = player.position.y - 54.0


func _process(_delta: float) -> void:
	var state := "AIRBORNE" if player.jump_component.is_airborne else "GROUNDED"
	var height := player.terrain_motor.elevation()
	# Probe with the same foot shape as movement, so a blocked approach names
	# the actual raised top rather than looking like a stuck input.
	var shape := player.get_node("BodyCollision") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	var foot := Rect2(shape.position - size * 0.5, size)
	var floor := terrain.surface_at(player.position.x, player.position.y, height + 0.5, foot)
	status.text = "HEIGHT %d | %s | %s | LIVES %d" % [height, state, floor.get("name", "--"), player.terrain_motor.remaining_lives]
	var ahead := terrain.surface_at(player.position.x, player.position.y - 12.0, INF, foot)
	if not player.jump_component.is_airborne and float(ahead.get("height", 0.0)) > height:
		status.text += "\nUP: %s  +%d  |  K + W: jump up" % [ahead.name, float(ahead.height) - height]


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_B:
		outlines.visible = not outlines.visible
