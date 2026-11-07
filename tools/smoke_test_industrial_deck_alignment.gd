extends "res://tools/smoke_test_industrial_terrain.gd"

func _run() -> void:
	var stage := await _new_stage()
	var terrain := stage.get_node("Terrain") as BeltTerrainMap
	var tops: Dictionary = {}
	for surface: Dictionary in terrain.surfaces:
		tops[surface["name"]] = surface
	var tower: Dictionary = tops["TowerTop"]
	var deck: Dictionary = tops["LoadingDeck"]
	var tower_edge := _ground_point(tower, 1, terrain.image_offset_y)
	var deck_edge := _ground_point(deck, 0, terrain.image_offset_y)
	_check(tower_edge.distance_to(deck_edge) < 12 and is_zero_approx((deck_edge - tower_edge).cross(Vector2.ONE)), "Tower and inset deck meet along the same projected edge in ground depth: %s vs %s" % [tower_edge, deck_edge])
	var tower_front := _ground_point(tower, 2, terrain.image_offset_y)
	var deck_front := _ground_point(deck, 3, terrain.image_offset_y)
	_check(is_zero_approx((tower_front - deck_edge).cross(deck_front - deck_edge)), "Tower right side shares deck left side instead of crossing in front")
	for name: String in ["LeftCrateTier1", "LeftCrateTier2", "LeftCrateTier3", "RightCrateTier1", "RightCrateTier2", "RightCrateTier3", "Conveyor"]:
		var surface: Dictionary = tops[name]
		var center := Vector2.ZERO
		for index: int in range(surface["polygon"].size()):
			center += _ground_point(surface, index, terrain.image_offset_y)
		center /= surface["polygon"].size()
		_check(terrain.floor_at(center.x, center.y, 192) == 192.0, name + " stands on deck 192")
	for point: Vector2 in [Vector2(736, 152), Vector2(800, 160), Vector2(888, 216)]:
		_check(terrain.floor_at(point.x, point.y, 192) == 192.0, "Ladder/door rests on deck at %s" % point)
	await AudioSettle.free_level(self, stage)
	for message: String in failures:
		push_error(message)
	if failures.is_empty():
		print("INDUSTRIAL_DECK_ALIGNMENT_SMOKE_TEST_PASS")
	quit(0 if failures.is_empty() else 1)


func _ground_point(surface: Dictionary, index: int, offset: float) -> Vector2:
	var vertex: Array = surface["polygon"][index]
	return Vector2(vertex[0], vertex[1] + float(surface["height"]) + offset)
