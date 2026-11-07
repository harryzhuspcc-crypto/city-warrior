extends Node2D

@onready var terrain: BeltTerrainMap = $Terrain
@onready var player: Player = $Actors/Player

func _ready() -> void:
	terrain.attach_actor(player)
	place_on(1)

func _process(_delta: float) -> void:
	$HUD/Status.text = "HEIGHT %d  |  %s" % [player.terrain_motor.elevation(), "AIRBORNE" if player.jump_component.is_airborne else "GROUNDED"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_2:
		place_on(event.physical_keycode - KEY_0)

func place_on(tier: int) -> void:
	var platform: Polygon2D = $Platforms.get_node("Ground" if tier == 0 else "Level%d" % tier)
	var points: PackedVector2Array = platform.top_points_in(self)
	var center := Vector2.ZERO
	for point: Vector2 in points:
		center += point
	center /= points.size()
	# The sample uses convex polygons, so their vertex average lies inside.
	player.position = Vector2(65, 245) if tier == 0 else center + Vector2(0, platform.height)
	player.combat_component.cancel_attack()
	player.input_component.clear_buffered_actions()
	player.velocity = Vector2.ZERO
	player.jump_component.ground_elevation = platform.height
	player.jump_component.land_immediately()
	player.terrain_motor.after_move()
