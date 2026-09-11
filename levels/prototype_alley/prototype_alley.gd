class_name PrototypeAlley
extends Node2D

@export var actors: Node2D
@export var walkable_bounds: Rect2 = Rect2(15.0, 108.0, 354.0, 92.0)


func _ready() -> void:
	assert(actors != null, "PrototypeAlley requires an Actors container")
	assert(actors.y_sort_enabled, "PrototypeAlley Actors must enable Y sorting")
